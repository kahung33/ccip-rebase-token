// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owener = makeAddr("owener");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owener);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = address(rebaseToken).call{value: 1e18}("");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        // 2. check our rebase token balance
        vm.deal(user, amount);
        // 3. warp the time and check the balance again
        // 4. warp the time again by the same amount and check the balance again
        vm.stopPrank();
    }
}
