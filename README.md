# Cross-chain Rebase Token

1. A protocol that allows user to deposit into a vault and in return, receiver rebase tokens that represent their underlying balance
2. Rebase toekn -> balance is dynamic to show the changing balance with time.
   - Balance increase linearly with time
   - mint tokens to our users every time they perform an action (minting, burning, transfering, or ... briding)
3. Interest rate
   - Individually set an interest rate or each user based on some global interest rate of the protocol at the time the user deposits into the vault.
   - This global interest rate can only decrease to incetivise/reward early adopters.


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