//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/*
 * @title Decentralized Stablecoin
 * @author Aleksa
 * Collateral: ETH, BTC
 * This coin is an ERC20 token pegged to USD, 1:1
 */

contract Stablecoin is ERC20Burnable {
    error Stablecoin__MustBeMoreThanZero();
    error Stablecoin__BurnAmountExceedsBalance();
    error Stablecoin__ZeroAddress();

    constructor() ERC20('Stablecoin', 'STC') {}

    function burn(uint256 _amount) public override {
        if(_amount <= 0) {
            revert Stablecoin__MustBeMoreThanZero();
        }
        if(balanceOf(msg.sender) <= _amount) {
            revert Stablecoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external returns(bool) {
        if(_to == address(0)) {
            revert Stablecoin__ZeroAddress();
        }
        if(_amount <= 0) {
            revert Stablecoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
