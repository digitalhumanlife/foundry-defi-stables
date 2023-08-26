//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author JW
 * @notice
 * This contract purposefully fails minting for testing purposes.
 */

contract MockERC20FailedMint is ERC20Burnable, Ownable {
    error MockERC20FailedMint__MustBeMoreThanZero();
    error MockERC20FailedMint__BurnAmount();
    error MockERC20FailedMint__NotZeroAddress();

    constructor() ERC20("Decentralized Stable Coin", "DSC") {}

    // function burn(uint256 _amount) public override onlyOwner {
    //     uint256 balance = balanceOf(msg.sender);
    //     if (_amount <= 0) {
    //         revert DecentralizedStableCoin__MustBeMoreThanZero();
    //     }
    //     if (_amount > balance) {
    //         revert DecentralizedStableCoin__BurnAmount();
    //     } else {
    //         super.burn(_amount);
    //     }
    // }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert MockERC20FailedMint__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert MockERC20FailedMint__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return false; // THIS IS THE CHANGE!
    }
}
