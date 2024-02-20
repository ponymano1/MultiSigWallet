pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract SomeContract {
    mapping(address => uint256) internal _receivedDonates;
    function donate(address to) payable public {
        _receivedDonates[to] += msg.value;
    }

    receive() payable external {
        _receivedDonates[msg.sender] += msg.value;
    }

    function getTotalBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getBalanceOf(address addr) public view returns (uint256) {
        return _receivedDonates[addr];
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    SomeContract public someContract;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public userReceiver;

    function setUp() public {
        address[] memory owners = new address[](3);
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        userReceiver = makeAddr("userReceiver");
        vm.deal(user1, 2000 ether);

        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;

        vm.startPrank(user1);
        {
            someContract = new SomeContract();
            wallet = new MultiSigWallet(owners, 2);
            wallet.deposit{value: 1000 ether}();
        }
        vm.stopPrank();
    }

    function testSubmitConfirmExecute() public {
        uint256 balanceBefore = address(wallet).balance;
        uint256 amount = 10 ether;
        bytes memory data = abi.encodeWithSignature("donate(address)", userReceiver);
        uint256 transactionId = wallet.getNextTransactionId();
        
        vm.prank(user1);
        wallet.submitTransaction(address(someContract), amount, data);
        
        vm.prank(user1);
        wallet.confirmTransaction(transactionId);

        vm.prank(user2);
        wallet.confirmTransaction(transactionId);

        vm.startPrank(user1);
        {
            wallet.executeTransaction(transactionId);
        }
        vm.stopPrank();

        assertEq(someContract.getBalanceOf(userReceiver), amount);
        assertEq(address(wallet).balance, balanceBefore - amount);
        assertEq(someContract.getTotalBalance(), amount);  
    }


    function testFail_canNotExecuteIfNotEnoughRequired() public {
        uint256 balanceBefore = address(wallet).balance;
        uint256 amount = 10 ether;
        bytes memory data = abi.encodeWithSignature("donate(address)", userReceiver);
        uint256 transactionId = wallet.getNextTransactionId();
        
        vm.prank(user1);
        wallet.submitTransaction(address(someContract), amount, data);
        
        vm.prank(user2);
        wallet.confirmTransaction(transactionId);

        vm.startPrank(user1);
        {
            wallet.executeTransaction(transactionId);
        }
        vm.stopPrank();

    }

    
}