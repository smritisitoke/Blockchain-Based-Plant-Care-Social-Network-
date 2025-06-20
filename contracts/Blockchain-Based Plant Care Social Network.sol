// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Project - Blockchain-Based Plant Care Social Network
 * @dev A decentralized platform for plant care management and community support
 * @author Plant Care Network Team
 */
contract Project {
    
    // Struct to represent a plant
    struct Plant {
        uint256 id;
        string name;
        string species;
        address owner;
        uint256 lastCareTime;
        uint256 careFrequency; // in days
        uint256 healthPoints;
        bool isAlive;
        string notes;
    }
    
    // Struct to represent a plant sitter
    struct PlantSitter {
        address sitterAddress;
        string name;
        uint256 reputation;
        uint256 stakedAmount;
        bool isAvailable;
        uint256 totalJobsCompleted;
    }
    
    // Struct for care requests
    struct CareRequest {
        uint256 plantId;
        address plantOwner;
        address assignedSitter;
        uint256 startDate;
        uint256 endDate;
        uint256 reward;
        bool isCompleted;
        bool isActive;
    }
    
    // State variables
    mapping(uint256 => Plant) public plants;
    mapping(address => PlantSitter) public plantSitters;
    mapping(uint256 => CareRequest) public careRequests;
    mapping(address => uint256[]) public userPlants;
    
    uint256 public plantCounter;
    uint256 public requestCounter;
    uint256 public constant MINIMUM_STAKE = 0.01 ether;
    uint256 public constant MAX_HEALTH_POINTS = 100;
    
    // Events
    event PlantRegistered(uint256 indexed plantId, address indexed owner, string name);
    event PlantCareProvided(uint256 indexed plantId, address indexed caregiver, uint256 timestamp);
    event SitterRegistered(address indexed sitter, string name, uint256 stakedAmount);
    event CareRequestCreated(uint256 indexed requestId, uint256 indexed plantId, uint256 reward);
    event CareRequestCompleted(uint256 indexed requestId, address indexed sitter);
    
    // Modifiers
    modifier onlyPlantOwner(uint256 _plantId) {
        require(plants[_plantId].owner == msg.sender, "Only plant owner can perform this action");
        _;
    }
    
    modifier plantExists(uint256 _plantId) {
        require(_plantId > 0 && _plantId <= plantCounter, "Plant does not exist");
        _;
    }
    
    modifier onlyRegisteredSitter() {
        require(plantSitters[msg.sender].sitterAddress == msg.sender, "Not a registered sitter");
        _;
    }
    
    /**
     * @dev Core Function 1: Register a new plant
     * @param _name Name of the plant
     * @param _species Species of the plant
     * @param _careFrequency How often the plant needs care (in days)
     * @param _notes Additional care notes
     * @return plantId The ID of the newly registered plant
     */
    function registerPlant(
        string memory _name,
        string memory _species,
        uint256 _careFrequency,
        string memory _notes
    ) external returns (uint256) {
        require(bytes(_name).length > 0, "Plant name cannot be empty");
        require(bytes(_species).length > 0, "Plant species cannot be empty");
        require(_careFrequency > 0 && _careFrequency <= 365, "Invalid care frequency");
        
        plantCounter++;
        uint256 newPlantId = plantCounter;
        
        plants[newPlantId] = Plant({
            id: newPlantId,
            name: _name,
            species: _species,
            owner: msg.sender,
            lastCareTime: block.timestamp,
            careFrequency: _careFrequency,
            healthPoints: MAX_HEALTH_POINTS,
            isAlive: true,
            notes: _notes
        });
        
        userPlants[msg.sender].push(newPlantId);
        
        emit PlantRegistered(newPlantId, msg.sender, _name);
        return newPlantId;
    }
    
    /**
     * @dev Core Function 2: Provide care for a plant
     * @param _plantId ID of the plant to care for
     * @param _careNotes Notes about the care provided
     */
    function providePlantCare(uint256 _plantId, string memory _careNotes) 
        external 
        plantExists(_plantId) 
    {
        Plant storage plant = plants[_plantId];
        require(plant.isAlive, "Cannot care for a dead plant");
        
        // Check if caller is authorized (owner or assigned sitter)
        bool isAuthorized = (plant.owner == msg.sender) || 
                           (isAssignedSitter(_plantId, msg.sender));
        require(isAuthorized, "Not authorized to care for this plant");
        
        // Update plant care time and health
        plant.lastCareTime = block.timestamp;
        
        // Restore health points (caring for plant improves health)
        if (plant.healthPoints < MAX_HEALTH_POINTS) {
            plant.healthPoints = MAX_HEALTH_POINTS;
        }
        
        // If care provided by sitter, update their reputation
        if (plant.owner != msg.sender && plantSitters[msg.sender].sitterAddress == msg.sender) {
            plantSitters[msg.sender].reputation += 10;
        }
        
        // Update notes if provided
        if (bytes(_careNotes).length > 0) {
            plant.notes = _careNotes;
        }
        
        emit PlantCareProvided(_plantId, msg.sender, block.timestamp);
        
        // Check and complete care request if exists
        completeCareRequestIfExists(_plantId, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Request plant sitting service
     * @param _plantId ID of the plant that needs care
     * @param _startDate Start date of care period (timestamp)
     * @param _endDate End date of care period (timestamp)
     */
    function requestPlantSitting(
        uint256 _plantId,
        uint256 _startDate,
        uint256 _endDate
    ) external payable plantExists(_plantId) onlyPlantOwner(_plantId) {
        require(plants[_plantId].isAlive, "Cannot request care for dead plant");
        require(_startDate >= block.timestamp, "Start date must be in the future");
        require(_endDate > _startDate, "End date must be after start date");
        require(msg.value > 0, "Must provide reward for sitter");
        
        requestCounter++;
        uint256 newRequestId = requestCounter;
        
        careRequests[newRequestId] = CareRequest({
            plantId: _plantId,
            plantOwner: msg.sender,
            assignedSitter: address(0),
            startDate: _startDate,
            endDate: _endDate,
            reward: msg.value,
            isCompleted: false,
            isActive: true
        });
        
        emit CareRequestCreated(newRequestId, _plantId, msg.value);
    }
    
    /**
     * @dev Register as a plant sitter
     * @param _name Name of the sitter
     */
    function registerAsSitter(string memory _name) external payable {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake amount");
        require(plantSitters[msg.sender].sitterAddress == address(0), "Already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        plantSitters[msg.sender] = PlantSitter({
            sitterAddress: msg.sender,
            name: _name,
            reputation: 100, // Starting reputation
            stakedAmount: msg.value,
            isAvailable: true,
            totalJobsCompleted: 0
        });
        
        emit SitterRegistered(msg.sender, _name, msg.value);
    }
    
    /**
     * @dev Accept a care request (for sitters)
     * @param _requestId ID of the care request to accept
     */
    function acceptCareRequest(uint256 _requestId) 
        external 
        onlyRegisteredSitter 
    {
        CareRequest storage request = careRequests[_requestId];
        require(request.isActive, "Request is not active");
        require(request.assignedSitter == address(0), "Request already assigned");
        require(plantSitters[msg.sender].isAvailable, "Sitter not available");
        
        request.assignedSitter = msg.sender;
        plantSitters[msg.sender].isAvailable = false;
    }
    
    /**
     * @dev Update plant health based on care timing
     * @param _plantId ID of the plant to update
     */
    function updatePlantHealth(uint256 _plantId) 
        external 
        plantExists(_plantId) 
    {
        Plant storage plant = plants[_plantId];
        
        if (!plant.isAlive) return;
        
        uint256 daysSinceLastCare = (block.timestamp - plant.lastCareTime) / 86400; // Convert to days
        
        if (daysSinceLastCare > plant.careFrequency) {
            uint256 healthDecay = (daysSinceLastCare - plant.careFrequency) * 5;
            
            if (healthDecay >= plant.healthPoints) {
                plant.healthPoints = 0;
                plant.isAlive = false;
            } else {
                plant.healthPoints -= healthDecay;
            }
        }
    }
    
    /**
     * @dev Complete care request and distribute rewards
     * @param _plantId Plant ID being cared for
     * @param _sitter Address of the sitter
     */
    function completeCareRequestIfExists(uint256 _plantId, address _sitter) internal {
        for (uint256 i = 1; i <= requestCounter; i++) {
            CareRequest storage request = careRequests[i];
            if (request.plantId == _plantId && 
                request.assignedSitter == _sitter && 
                request.isActive && 
                !request.isCompleted &&
                block.timestamp >= request.startDate &&
                block.timestamp <= request.endDate) {
                
                request.isCompleted = true;
                request.isActive = false;
                
                // Transfer reward to sitter
                payable(_sitter).transfer(request.reward);
                
                // Update sitter stats
                plantSitters[_sitter].totalJobsCompleted++;
                plantSitters[_sitter].isAvailable = true;
                
                emit CareRequestCompleted(i, _sitter);
                break;
            }
        }
    }
    
    /**
     * @dev Check if address is assigned sitter for a plant
     * @param _plantId Plant ID to check
     * @param _sitter Address to check
     * @return bool True if sitter is assigned to plant
     */
    function isAssignedSitter(uint256 _plantId, address _sitter) internal view returns (bool) {
        for (uint256 i = 1; i <= requestCounter; i++) {
            CareRequest storage request = careRequests[i];
            if (request.plantId == _plantId && 
                request.assignedSitter == _sitter && 
                request.isActive &&
                block.timestamp >= request.startDate &&
                block.timestamp <= request.endDate) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Get plant details
     * @param _plantId ID of the plant
     * @return Plant struct data
     */
    function getPlant(uint256 _plantId) 
        external 
        view 
        plantExists(_plantId) 
        returns (Plant memory) 
    {
        return plants[_plantId];
    }
    
    /**
     * @dev Get user's plants
     * @param _user Address of the user
     * @return Array of plant IDs owned by user
     */
    function getUserPlants(address _user) external view returns (uint256[] memory) {
        return userPlants[_user];
    }
    
    /**
     * @dev Get sitter details
     * @param _sitter Address of the sitter
     * @return PlantSitter struct data
     */
    function getSitter(address _sitter) external view returns (PlantSitter memory) {
        return plantSitters[_sitter];
    }
    
    /**
     * @dev Get care request details
     * @param _requestId ID of the care request
     * @return CareRequest struct data
     */
    function getCareRequest(uint256 _requestId) external view returns (CareRequest memory) {
        return careRequests[_requestId];
    }
    
    /**
     * @dev Get total number of plants registered
     * @return Total plant count
     */
    function getTotalPlants() external view returns (uint256) {
        return plantCounter;
    }
    
    /**
     * @dev Get total number of care requests
     * @return Total request count
     */
    function getTotalRequests() external view returns (uint256) {
        return requestCounter;
    }
}
