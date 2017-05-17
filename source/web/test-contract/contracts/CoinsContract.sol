pragma solidity ^0.4.6;
contract CoinsContract  {
    uint public balance;
    function CoinsContract(uint initial) {
        balance = initial;
    }
    function addCoins(uint add) returns (uint b) {
       b = balance + add;
       return b;
    }
    function subtractCoins(uint add) returns (uint b) {
       b = balance - add;
       return b;
    }
}