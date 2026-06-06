// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract AeroTrack {


    // 1. TYPES DE DONNÉES

    // Enum = liste fermée d'états possibles pour une pièce
    enum PartStatus { 
        Manufactured,   // 0 — vient d'être fabriquée
        InTransit,      // 1 — en cours de transfert
        Installed,      // 2 — installée sur un avion
        Retired         // 3 — mise hors service
    }

    // Struct = objet représentant une pièce physique
    struct Part {
        uint256 serialNumber;   // Numéro de série unique
        string  partName;       // Nom 
        address manufacturer;   // Adresse Ethereum du fabricant
        address currentOwner;   // Adresse du propriétaire actuel
        PartStatus status;      // État actuel de la pièce
        bool exists;            // Flag de sécurité 
    }

    // 2. VARIABLES D'ÉTAT 

    address public regulatoryAuthority; // L'autorité (FAA/EASA) = celui qui déploie

    // Mapping : numéro de série → struct Part
    // Comme un dictionnaire : parts[999] retourne la pièce #999
    mapping(uint256 => Part) public parts;

    // 3. ÉVÉNEMENTS

    // "indexed" permet de filtrer rapidement par serialNumber dans les logs
    event PartManufactured(uint256 indexed serialNumber, string partName, address manufacturer);
    event OwnershipTransferred(uint256 indexed serialNumber, address oldOwner, address newOwner);
    event MaintenanceLogged(uint256 indexed serialNumber, address mechanic, string report);

    // 4. CONSTRUCTEUR — s'exécute UNE SEULE FOIS au déploiement

    constructor() {
        regulatoryAuthority = msg.sender; // Le déployeur devient l'autorité réglementaire
    }

    // 5. MODIFIERS — vérifient des conditions AVANT d'exécuter une fonction
    //    Le "_;" dit à Solidity "maintenant exécute le reste de la fonction"

    // Seule l'autorité réglementaire peut appeler les fonctions protégées
    modifier onlyAuthority() {
        require(msg.sender == regulatoryAuthority, "Error: You are not the Authority.");
        _;
    }

    // Vérifie que la pièce existe vraiment dans le registry
    modifier partExists(uint256 _serialNumber) {
        require(parts[_serialNumber].exists == true, "Error: Part does not exist in registry.");
        _;
    }

    // Seul le propriétaire actuel de la pièce peut agir dessus
    modifier onlyPartOwner(uint256 _serialNumber) {
        require(parts[_serialNumber].currentOwner == msg.sender, "Error: You do not own this part.");
        _;
    }

    // 6. FONCTIONS PRINCIPALES

    function manufacturePart(uint256 _serialNumber, string memory _partName) public {
        // Sécurité : on rejette si le numéro de série est déjà utilisé
        require(parts[_serialNumber].exists == false, "Error: Serial Number already registered!");

        // Création de la pièce dans le storage de la blockchain
        parts[_serialNumber] = Part({
            serialNumber:  _serialNumber,
            partName:      _partName,
            manufacturer:  msg.sender,
            currentOwner:  msg.sender, // Le fabricant est le premier propriétaire
            status:        PartStatus.Manufactured,
            exists:        true
        });

        // Émission de l'événement — trace immuable dans les logs
        emit PartManufactured(_serialNumber, _partName, msg.sender);
    }

    
    function transferPart(uint256 _serialNumber, address _newOwner)
        public
        partExists(_serialNumber)       // 1er garde : la pièce doit exister
        onlyPartOwner(_serialNumber)    // 2e garde : seul le propriétaire peut transférer
    {
        require(_newOwner != address(0), "Error: Cannot transfer to zero address.");

        address oldOwner = parts[_serialNumber].currentOwner;

        // Mise à jour du propriétaire et du statut
        parts[_serialNumber].currentOwner = _newOwner;
        parts[_serialNumber].status = PartStatus.InTransit;

        emit OwnershipTransferred(_serialNumber, oldOwner, _newOwner);
    }

    
    function logMaintenance(uint256 _serialNumber, string memory _report)
        public
        partExists(_serialNumber)
        onlyPartOwner(_serialNumber)
    {
        // Le rapport est émis en log — pas stocké en storage 
        emit MaintenanceLogged(_serialNumber, msg.sender, _report);

        // La pièce passe en état "installée" après maintenance
        parts[_serialNumber].status = PartStatus.Installed;
    }
}
