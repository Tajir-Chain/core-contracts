// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title TajirToken — L1 bridged gas token (upgradeable, UUPS)
/// @notice Fixed-supply ERC20 used as the Tajir L2 gas token. Locked on L1, native on L2.
/// @dev v1 mints the full supply once at initialize() to `initialHolder` and has no
///      mint / burn surface. Governance, participation, and voting live in the L2 TajirToken.
///      Upgrade authority is `UPGRADER_ROLE` via AccessControlUpgradeable.
contract TajirToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    error Tajir__InvalidAddress();
    error Tajir__ZeroSupply();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @param name_ ERC20 name
    /// @param symbol_ ERC20 symbol
    /// @param initialSupply whole-token initial supply (decimals applied internally)
    /// @param initialHolder recipient of the full supply at genesis (Bootstrap Safe)
    /// @param upgrader address authorised to call upgradeToAndCall (Bootstrap Safe)
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialHolder,
        address upgrader
    ) public initializer {
        if (initialHolder == address(0)) revert Tajir__InvalidAddress();
        if (upgrader == address(0)) revert Tajir__InvalidAddress();
        if (initialSupply == 0) revert Tajir__ZeroSupply();

        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, upgrader);
        _grantRole(UPGRADER_ROLE, upgrader);

        _mint(initialHolder, initialSupply * 10 ** decimals());
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal override onlyRole(UPGRADER_ROLE) {}
}
