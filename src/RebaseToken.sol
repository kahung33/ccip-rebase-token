// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author OpenAI
 * @notice This is a cross-chain token that incentivises users to deposit into a vault.
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 originalInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5 * PRECISION_FACTOR / 1e8; //
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Sets the interest rate in the contract
     * @param _newInterestRate The new interest rate to be set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set the interest rate
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Gets the principle balance of the user. This is the balance of tokens that have been minted to the user, not including any interest that has accrued since the last interacted with the contract
     * @param _user The user to get the principle balance of
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mints rebase tokens to the user when they deposit into the vault
     * @param _to The address to mint the rebase tokens to
     * @param _amount The amount of rebase tokens to mint
     */

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burns rebase tokens from the user when they withdraw from the vault
     * @param _from The address to burn the rebase tokens from
     * @param _amount The amount of rebase tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Calculates the balance of user include the interest that has accumulated since the last update
     * (principle balance + some interest that has accrued)
     * @param _user The user to calculate the balance of
     * @return The balance of the user including the interest that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance of the user (ie number of tokens that have actually been minted to the user)
        // multiply the pricipal blance by the interest that has accumulated in the time since the balance
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Transfers rebase tokens from the user to another user
     * @param _recipient The address to transfer the rebase tokens to
     * @param _amount The amount of rebase tokens to transfer
     * @return True if the transfer was successful, false otherwise
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfers rebase tokens from the user to another user
     * @param _sender The address to transfer the rebase tokens from
     * @param _recipient The address to transfer the rebase tokens to
     * @param _amount The amount of rebase tokens to transfer
     * @return True if the transfer was successful, false otherwise
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculates the accumulated interest since the last update
     * @param _user The user to calculate the accumulated interest for
     * @return linearInterest The accumulated interest since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accrued since the last update
        // This is going to be linear growth with time
        //(1) calculate the time since the last update
        //(2) calculate the amount of linear growth
        //(principal amount) + (principal amount * user interest rate * time elapsed)
        // deposit 10 tokens
        // interest rate 0.5 tokens per second
        // time elapsed 2 seconds
        // 10 + (10* 0.5 *2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mints the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
     * @param _user The user to mint the accrued interest for
     */
    function _mintAccuredInterest(address _user) internal {
        // (1) find their current balance of rebase tokens that have been minted to the user -> principal balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // (3) calculate the number of tokens that need to be minted to the user (2) - (1) -> amountToMint
        uint256 amountToMint = currentBalance - previousPrincipalBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, amountToMint);
    }

    /**
     * @notice Gets the interest rate is currently set for the contract. Any future depositors will receive this interest rate
     * @return The interest rate for the user
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Gets the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

}
