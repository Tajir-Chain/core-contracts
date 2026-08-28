// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title ITajirToken
/// @notice Interface for the TajirToken ERC-20 L1 gas token
/// @dev Covers the full external surface: ERC-20, ERC-2612 Permit, Burn, and UUPS upgrade
interface ITajirToken {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when a zero address is provided where a non-zero address is required
    error Tajir__InvalidAddress();

    /// @notice Thrown when the initial supply value is zero
    error Tajir__ZeroSupply();

    // -------------------------------------------------------------------------
    // Initializer
    // -------------------------------------------------------------------------

    /// @notice Initializes the token behind an ERC-1967 proxy
    /// @param name_ ERC-20 token name
    /// @param symbol_ ERC-20 token symbol
    /// @param initialSupply Whole-token initial supply (decimals applied internally)
    /// @param initialHolder Address that receives the full genesis supply
    /// @param upgrader Address granted `DEFAULT_ADMIN_ROLE` and `UPGRADER_ROLE`
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address initialHolder,
        address upgrader
    ) external;

    // -------------------------------------------------------------------------
    // Access Control
    // -------------------------------------------------------------------------

    /// @notice The keccak256 hash of the UPGRADER_ROLE identifier
    function UPGRADER_ROLE() external view returns (bytes32);

    // -------------------------------------------------------------------------
    // ERC-20 (subset of standard interface for reference)
    // -------------------------------------------------------------------------

    /// @notice Returns the total token supply
    function totalSupply() external view returns (uint256);

    /// @notice Returns the token balance of `account`
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers `amount` tokens to `to`
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining allowance that `spender` has over `owner`'s tokens
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approves `spender` to spend up to `amount` tokens
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers `amount` tokens from `from` to `to` using the allowance mechanism
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // -------------------------------------------------------------------------
    // ERC-20 Burnable
    // -------------------------------------------------------------------------

    /// @notice Destroys `amount` tokens from the caller's balance
    function burn(uint256 amount) external;

    /// @notice Destroys `amount` tokens from `account` using the caller's allowance
    function burnFrom(address account, uint256 amount) external;

    // -------------------------------------------------------------------------
    // EIP-2612 Permit
    // -------------------------------------------------------------------------

    /// @notice Sets `value` as the allowance of `spender` over the `owner`'s tokens via a signed permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Returns the current EIP-2612 nonce for `owner`
    function nonces(address owner) external view returns (uint256);

    /// @notice Returns the domain separator used in the encoding of the signature for `permit`
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
