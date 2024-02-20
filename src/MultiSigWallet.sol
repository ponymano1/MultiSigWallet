// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract MultiSigWallet {
    address[] public owners;
    uint256 public immutable numOfRequired;
    uint256 internal transactionIdGen;
    mapping(address => bool) internal _isOwner;
    mapping(uint => Transaction) public transactions;
    mapping(uint => mapping(address => bool)) public isConfirmed;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(address indexed owner, uint indexed transactionId, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed transactionId);
    event RevokeConfirmation(address indexed owner, uint indexed transactionId);
    event ExecuteTransaction(address indexed owner, uint indexed transactionId);

    error ZeroOwners();
    error InvaidNumOfRequered();
    error NotOwner();
    error TransactionAlreadyExecuted();
    error TransactionDoesNotExist();
    error TransactionAlreadyConfirmed();
    error TransactionNotConfirmed();
    error TransactionNotReachedRequired();
    error ExecuteFailed();
    

    modifier onlyOwner() {
        if (!_isOwner[msg.sender]) {
            revert NotOwner();
        }
        _;
    }

    
    constructor(address[] memory _owners, uint _numOfRequired) {
        if (_owners.length == 0) {
            revert ZeroOwners();
        }

        if (_numOfRequired == 0) {
            revert InvaidNumOfRequered();
        }

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (_isOwner[owner] || owner == address(0)) {
                continue;
            }
            owners.push(owner);
            _isOwner[owner] = true;
        }
        
        if (_numOfRequired > owners.length) {
            revert InvaidNumOfRequered();
        }
        numOfRequired = _numOfRequired;
        transactionIdGen = 1;
    }
    
    function deposit() public payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    
    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        Transaction memory transaction = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        });
        transactions[transactionIdGen++] = transaction;
        emit SubmitTransaction(msg.sender, transactionIdGen - 1, _to, _value, _data);
    }
    
    function confirmTransaction(uint _transactionId) public onlyOwner {
        if (_transactionId >= transactionIdGen) {
            revert TransactionDoesNotExist();
        }

        if (transactions[_transactionId].executed) {
            revert TransactionAlreadyExecuted();
        }

        if (isConfirmed[_transactionId][msg.sender]) {
            revert TransactionAlreadyConfirmed();
        }

        isConfirmed[_transactionId][msg.sender] = true;
        transactions[_transactionId].numConfirmations++;
        emit ConfirmTransaction(msg.sender, _transactionId);
    }
    
    function executeTransaction(uint _transactionId) public {
        if (_transactionId >= transactionIdGen) {
            revert TransactionDoesNotExist();
        }

        if (transactions[_transactionId].executed) {
            revert TransactionAlreadyExecuted();
        }

        if (transactions[_transactionId].numConfirmations < numOfRequired) {
            revert TransactionNotReachedRequired();
        }

        transactions[_transactionId].executed = true;
        (bool success, ) = transactions[_transactionId].to.call{value: transactions[_transactionId].value}(transactions[_transactionId].data);
        if (!success) {
            revert ExecuteFailed();
        }
    }
    
    function revokeConfirmation(uint _transactionId) public {
        if (_transactionId >= transactionIdGen) {
            revert TransactionDoesNotExist();
        }

        if (transactions[_transactionId].executed) {
            revert TransactionAlreadyExecuted();
        }

        if (!isConfirmed[_transactionId][msg.sender]) {
            revert TransactionNotConfirmed();
        }

        isConfirmed[_transactionId][msg.sender] = false;
        transactions[_transactionId].numConfirmations--;
    }
    
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
    
    
    function getTransaction(uint _transactionId) public view returns (address to, uint value, bytes memory data, bool executed, uint numConfirmations) {
        if (_transactionId >= transactionIdGen) {
            revert TransactionDoesNotExist();
        }        

        Transaction memory transaction = transactions[_transactionId];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.numConfirmations);
    }
    
    function isOwner(address owner) public view returns (bool) {
        return _isOwner[owner];
    }
    

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }   

    function getNextTransactionId() public view returns (uint) {
        return transactionIdGen;
    }
}