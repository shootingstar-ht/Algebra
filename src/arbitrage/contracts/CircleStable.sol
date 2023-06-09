// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import './ERC20Permit.sol';

contract CircleStable is ERC20Permit {
    constructor() ERC20Permit('Circle Stable', 'USDC', 6, 1e18) {}
}
