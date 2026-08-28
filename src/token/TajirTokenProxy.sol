// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title TajirTokenProxy
/// @notice Thin wrapper around OpenZeppelin's standard ERC1967Proxy so that
///         `forge inspect` / our deploy scripts can locate the proxy bytecode
///         under this project's compilation scope. Identical behaviour to
///         ERC1967Proxy — no storage, no logic of its own. Deployed with
///         (impl, initializeCalldata) as ctor args.
contract TajirTokenProxy is ERC1967Proxy {
    constructor(
        address implementation,
        bytes memory data
    ) ERC1967Proxy(implementation, data) {}
}
