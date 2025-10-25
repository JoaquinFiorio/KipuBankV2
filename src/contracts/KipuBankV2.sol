// SPDX-License-Identifier: MIT
pragma solidity >0.8.29;

import {AccessControl} from "@openzeppelin/contracts@5.3.0/access/AccessControl.sol";
import {AccessControlContract} from "./AccessControlContract.sol";
import {AggregatorV3Interface} from "@chainlink/contracts@1.5.0/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title KipuBankV2
 * @notice Simple bank contract for ETH and USDC deposits and withdrawals
 *         Users depositing above a threshold are rewarded with an NFT
 * @dev Uses Chainlink ETH/USD price feed for USD calculations and 
 *      integrates with an external AccessControlContract for NFT minting
 */
contract KipuBankV2 is AccessControl {
    /// @notice Structure to store individual vault information
    struct Bank {
        uint256 eth;                 // Amount of ETH deposited by user
        uint256 usdc;                // Amount of USDC deposited by user
        uint256 total;               // Total balance in USD (eth * price + usdc)
        uint256 totalDeposited;      // Total deposited in USD
        uint256 totalWithdrawals;    // Total withdrawn in USD
        uint256 totalDepositsCount;  // Count of deposits
        uint256 totalWithdrawalsCount;// Count of withdrawals
    }

    // =======================
    //         ERRORS
    // =======================
    error KipuBank_ZeroDeposit();
    error KipuBank_ZeroWithdrawal();
    error KipuBank_BankCapExceeded(uint256 requested, uint256 available);
    error KipuBank_WithdrawalExceedsCap(uint256 requested, uint256 cap);
    error KipuBank_InsufficientVaultBalance(address account, uint256 balance, uint256 requested);
    error KipuBank_TransferFailed(bytes reason);
    error KipuBank_ReentrantCall();

    // =======================
    //       STATE VARIABLES
    // =======================
    uint256 public immutable i_bankCap;          // Maximum total ETH-equivalent the bank can hold
    uint256 public immutable i_withdrawalCap;    // Maximum withdrawal per transaction
    IERC20 public immutable USDC;                // USDC token contract
    uint256 public constant NFT_THRESHOLD = 1 ether; // Threshold for NFT reward

    AggregatorV3Interface internal dataFeed;     // Chainlink ETH/USD price feed
    AccessControlContract public nftContract;    // NFT contract integration

    mapping(address => Bank) public s_vaults;   // User vault mapping
    mapping(address => bool) public s_hasNFT;   // Tracks NFT ownership per user
    mapping(address => uint64) private s_depositsCountBy;     // Deposits count per user
    mapping(address => uint64) private s_withdrawalsCountBy;  // Withdrawals count per user

    uint128 private s_totalDeposited;           // Total ETH-equivalent deposited globally
    uint64 private s_totalDepositsCount;       // Global deposit counter
    uint64 private s_totalWithdrawalsCount;    // Global withdrawal counter
    uint8 private s_locked;                     // Reentrancy lock

    // =======================
    //          EVENTS
    // =======================
    /// @notice Emitted when ETH is deposited
    event Deposit(address indexed from, uint256 amountETH);

    /// @notice Emitted when USDC is deposited
    event DepositUSDC(address indexed from, uint256 amountUSDC);

    /// @notice Emitted when ETH is withdrawn
    event Withdrawal(address indexed from, uint256 amountETH);

    /// @notice Emitted when USDC is withdrawn
    event WithdrawalUSDC(address indexed from, uint256 amountUSDC);

    /// @notice Emitted when NFT is granted to a user
    event NFTGranted(address indexed to, uint256 tokenId);

    // =======================
    //        CONSTRUCTOR
    // =======================
    /**
     * @notice Initializes the bank contract
     * @param bankCap Maximum bank capacity in ETH equivalent
     * @param withdrawalCap Maximum withdrawal allowed per transaction
     * @param nftAddress Address of the NFT contract
     * @param usdcToken Address of the USDC token contract
     */
    constructor(
        uint256 bankCap,
        uint256 withdrawalCap,
        address nftAddress,
        address usdcToken
    ) {
        i_bankCap = bankCap;
        i_withdrawalCap = withdrawalCap;
        nftContract = AccessControlContract(nftAddress);
        USDC = IERC20(usdcToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    // =======================
    //      MODIFIERS
    // =======================
    /**
     * @notice Prevents reentrancy attacks
     */
    modifier nonReentrant() {
        if (s_locked == 1) revert KipuBank_ReentrantCall();
        s_locked = 1;
        _;
        s_locked = 0;
    }

    // =======================
    //      DEPOSIT FUNCTIONS
    // =======================
    /**
     * @notice Deposit ETH into the bank
     */
    function deposit() external payable {
        _depositETH(msg.sender, msg.value);
    }

    /**
     * @notice Fallback function for direct ETH transfers
     */
    receive() external payable {
        _depositETH(msg.sender, msg.value);
    }

    /**
     * @notice Fallback function for unknown calls with ETH
     */
    fallback() external payable {
        _depositETH(msg.sender, msg.value);
    }

    /**
     * @notice Internal logic for ETH deposit
     * @param _from User address
     * @param _value Amount of ETH
     */
    function _depositETH(address _from, uint256 _value) internal {
        int256 ethPrice = getChainlinkDataFeedLatestAnswer(); // Price in USD * 1e8

        if (_value == 0) revert KipuBank_ZeroDeposit();

        uint256 available = i_bankCap - uint256(s_totalDeposited);
        if (_value > available) revert KipuBank_BankCapExceeded(_value, available);

        Bank storage vault = s_vaults[_from];
        uint256 depositInUSD = (_value * uint256(ethPrice)) / 1e8;

        unchecked {
            vault.eth += _value;
            vault.total += depositInUSD;
            vault.totalDeposited += depositInUSD;
            vault.totalDepositsCount++;
        }

        s_totalDeposited += uint128(_value);  
        ++s_totalDepositsCount;             
        ++s_depositsCountBy[_from];

        emit Deposit(_from, _value);

        _verifyMintToken(vault, ethPrice, _from);
    }

    /**
     * @notice Deposit USDC into the bank
     * @param amount Amount of USDC tokens
     */
    function depositUSDC(uint256 amount) external nonReentrant {
        if (amount == 0) revert KipuBank_ZeroDeposit();

        int256 ethPrice = getChainlinkDataFeedLatestAnswer();

        bool success = USDC.transferFrom(msg.sender, address(this), amount);
        if (!success) revert KipuBank_TransferFailed("USDC transfer failed");

        uint256 ethEquivalent = (amount * 1e8) / uint256(ethPrice);
        uint256 available = i_bankCap - uint256(s_totalDeposited);
        if (ethEquivalent > available) revert KipuBank_BankCapExceeded(ethEquivalent, available);

        Bank storage vault = s_vaults[msg.sender];

        unchecked {
            vault.usdc += amount;
            vault.total += amount;
            vault.totalDeposited += amount;
            vault.totalDepositsCount++;
        }

        // Global totals / counters remain checked
        s_totalDeposited += uint128(ethEquivalent);
        ++s_totalDepositsCount;
        ++s_depositsCountBy[msg.sender];

        emit DepositUSDC(msg.sender, amount);

        _verifyMintToken(vault, ethPrice, msg.sender);
    }

    // =======================
    //      WITHDRAW FUNCTIONS
    // =======================
    /**
     * @notice Withdraw ETH from bank
     * @param _amount Amount in ETH to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert KipuBank_ZeroWithdrawal();
        if (_amount > i_withdrawalCap) revert KipuBank_WithdrawalExceedsCap(_amount, i_withdrawalCap);

        int256 ethPrice = getChainlinkDataFeedLatestAnswer();

        Bank storage vault = s_vaults[msg.sender];
        if (_amount > vault.eth)
            revert KipuBank_InsufficientVaultBalance(msg.sender, vault.eth, _amount);

        uint256 withdrawInUSD = (_amount * uint256(ethPrice)) / 1e8;

        unchecked {
            vault.eth -= _amount;
            vault.total -= withdrawInUSD;
            vault.totalWithdrawals += withdrawInUSD;
            vault.totalWithdrawalsCount++;
        }

        // Global counters / totals remain checked
        s_totalDeposited -= uint128(_amount);
        ++s_totalWithdrawalsCount;
        ++s_withdrawalsCountBy[msg.sender];

        emit Withdrawal(msg.sender, _amount);

        (bool success, bytes memory reason) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert KipuBank_TransferFailed(reason);
    }

    /**
     * @notice Withdraw USDC from bank
     * @param amount Amount of USDC to withdraw
     */
    function withdrawUSDC(uint256 amount) external nonReentrant {
        if (amount == 0) revert KipuBank_ZeroWithdrawal();
        if (amount > i_withdrawalCap) revert KipuBank_WithdrawalExceedsCap(amount, i_withdrawalCap);

        int256 ethPrice = getChainlinkDataFeedLatestAnswer();

        Bank storage vault = s_vaults[msg.sender];
        if (amount > vault.usdc)
            revert KipuBank_InsufficientVaultBalance(msg.sender, vault.usdc, amount);

        uint256 ethEquivalent = (amount * 1e8) / uint256(ethPrice);

        unchecked {
            vault.usdc -= amount;
            vault.total -= amount;
            vault.totalWithdrawals += amount;
            vault.totalWithdrawalsCount++;
        }

        // Global totals remain checked
        s_totalDeposited -= uint128(ethEquivalent);
        ++s_totalWithdrawalsCount;
        ++s_withdrawalsCountBy[msg.sender];

        emit WithdrawalUSDC(msg.sender, amount);

        bool success = USDC.transfer(msg.sender, amount);
        if (!success) revert KipuBank_TransferFailed("USDC transfer failed");
    }

    // =======================
    //        NFT LOGIC
    // =======================
    /**
     * @notice Check if user qualifies for NFT and mint if eligible
     * @param _vault User's bank struct
     * @param _latestAnswer ETH/USD price from Chainlink
     * @param _from User address
     */
    function _verifyMintToken(Bank storage _vault, int256 _latestAnswer, address _from) internal {
        if (!s_hasNFT[_from] && _vault.total >= ((NFT_THRESHOLD * uint256(_latestAnswer)) / 1e8)) {
            _grantNFT(_from);
        }
    }

    /**
     * @notice Mint NFT for user
     * @param user Address receiving NFT
     */
    function _grantNFT(address user) internal {
        s_hasNFT[user] = true;
        uint256 tokenId = nftContract.safeMint(user, "NFTmetadataURI");
        emit NFTGranted(user, tokenId);
    }

    // =======================
    //       VIEW FUNCTIONS
    // =======================
    /**
     * @notice Returns the deposit and withdrawal counts for a user
     * @param _account User address
     */
    function accountCounts(address _account) external view returns (uint256, uint256) {
        return (s_depositsCountBy[_account], s_withdrawalsCountBy[_account]);
    }

    /**
     * @notice Returns the ETH balance of the contract
     */
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns latest ETH/USD price from Chainlink feed
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int256) {
        (, int256 answer, , , ) = dataFeed.latestRoundData();
        return answer;
    }
}
