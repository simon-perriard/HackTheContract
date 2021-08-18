// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PayChecks is Ownable {

    struct Employee {
        address employeeAddress;
        uint16 payGradeId;
    }

    string public companyName;
    uint256 public lastPaymentTime = 0;
    Employee[] public employees;
    uint256[] public payGrades;
    mapping (address => uint32) public employeesId;

    constructor(string memory _companyName, Employee[] memory _employees, uint256[] memory _payGrades) isNotContract(_employees) {
        companyName = _companyName;
        payGrades = _payGrades;

        for (uint32 i = 0; i < _employees.length; i++) {
            
            // employees = _employees not supported yet
            // so copy one by one
            employees.push(_employees[i]);
            
            // Check that pay grade of each employee is in the _payGrades id range
            require(_employees[i].payGradeId < _payGrades.length);
            
            address employeeAddress = _employees[i].employeeAddress;
            employeesId[employeeAddress] = i;
        }
    }

    /// @notice check that each employee is not a contract
    modifier isNotContract(Employee[] memory _employees) {

        for (uint32 i = 0; i < _employees.length; i++) {
            address employeeAddress = _employees[i].employeeAddress;
            assembly {
                if iszero(employeeAddress) {revert(0,0)}
                let size := extcodesize(employeeAddress)
                if not(iszero(size)) {revert(0,0)}
            }
        }
        _;
    }

    modifier isEmployee(address _address) {
        require(employees[employeesId[_address]].employeeAddress == _address,
        "This address does not correspond to any employee");
        _;
    }

    modifier isValidPayGradeId(uint16 _payGradeId) {
        require(_payGradeId < payGrades.length, "Invalid pay grade ID");
        _;
    }
    
    /// @notice Allows to add employees after contract construction
    function addEmployee(uint16 _newEmployeePayGradeId, address _newEmployeeAddress) external onlyOwner isValidPayGradeId(_newEmployeePayGradeId) {
        require(_newEmployeeAddress != address(0x0));
        // Check that employee is not already registered
        require(employees.length == 0 || 
                employees[employeesId[_newEmployeeAddress]].employeeAddress != _newEmployeeAddress,
                "This address already corresponds to an employee");
        
        // Next employee id is current employees array length
        employeesId[_newEmployeeAddress] = uint32(employees.length);
        employees.push(Employee(_newEmployeeAddress, _newEmployeePayGradeId));
    }

    /// @notice pay all employees
    function runSalaryPayment() external payable onlyOwner {
        for(uint32 i = 0; i < employees.length; i++) {
            Employee memory current = employees[i];
            payable(current.employeeAddress).transfer(payGrades[current.payGradeId]);
        }
        lastPaymentTime = block.timestamp;
    }

    /// @notice compute the sum of all the salaries
    function computeTotalSalarialMass() external view returns (uint256) {
        uint256 total = 0;
        for(uint32 i = 0; i < employees.length; i++) {
            Employee memory current = employees[i];
            total += payGrades[current.payGradeId];
        }
        return total;
    }

    /// @notice change an employee's pay grade
    function changePayGradeForEmployee(uint16 _newPayGradeId, address _employeeAddress) external onlyOwner isEmployee(_employeeAddress) isValidPayGradeId(_newPayGradeId){
        employees[employeesId[_employeeAddress]].payGradeId = _newPayGradeId;
    }

    /// @notice update the amount of a pay grade
    function updatePayGrade(uint16 _payGradeId, uint256 _newAmount) external onlyOwner isValidPayGradeId(_payGradeId) {
        payGrades[_payGradeId] = _newAmount;
    }

    /// @notice add a new pay grade
    function addPayGrade(uint16 _amount) external onlyOwner {
        payGrades.push(_amount);
    }
}