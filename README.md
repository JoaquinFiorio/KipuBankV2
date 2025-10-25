# \# 🏦 KipuBankV2 — Hybrid ETH \& USDC Bank with NFT Rewards

# 

# \## Overview

# 

# KipuBankV2 is a hybrid smart contract that allows users to deposit and withdraw both ETH and USDC, while maintaining individual vault balances and global accounting.  

# The contract also integrates with Chainlink for real-time ETH/USD pricing and with an external AccessControl-based NFT contract, rewarding users with an NFT once their total balance exceeds a certain USD threshold.

# 

# It is designed to be secure, gas-optimized, and reentrancy-protected, implementing fine-grained overflow control using unchecked blocks where mathematically safe.

# 

# ---

# 

# \## ✨ Key Features

# 

# \- Multi-asset vaults for ETH and USDC with personal accounting.

# \- Global tracking of total deposits and withdrawals.

# \- NFT rewards for users who surpass a balance threshold.

# \- Chainlink price feed integration for accurate USD valuation.

# \- Gas-optimized arithmetic using safe unchecked operations.

# \- Reentrancy protection and access control.

# 

# ---

# 

# \## 🧩 Contract Architecture

# 

# Each user has a personal vault that tracks ETH and USDC balances, total value in USD, cumulative deposits and withdrawals, and operation counts.  

# All user vaults are stored in an internal mapping.  

# Global counters are maintained for total deposited amount and total operations.

# 

# ---

# 

# \## ⚙️ Constructor Parameters

# 

# \- \*\*bankCap\*\* — Maximum ETH-equivalent the contract can hold.  

# \- \*\*withdrawalCap\*\* — Maximum withdrawal allowed per transaction.  

# \- \*\*nftAddress\*\* — Address of the external NFT contract.  

# \- \*\*usdcToken\*\* — Address of the deployed USDC token contract.

# 

# ---

# 

# \## 🔒 Security Design

# 

# | Mechanism | Description |

# |------------|-------------|

# | Reentrancy Lock | Manual protection using a locked flag. |

# | Overflow Protection | Safe arithmetic with selective unchecked blocks. |

# | Bank Capacity Limit | Prevents exceeding maximum contract liquidity. |

# | Withdrawal Cap | Limits per-transaction withdrawals. |

# | Custom Errors | Gas-efficient revert handling. |

# | NFT Tracking | Prevents multiple NFTs per user. |

# 

# ---

# 

# \## 🧠 Functional Overview

# 

# \*\*Deposits and Withdrawals\*\*  

# Users can deposit or withdraw both ETH and USDC.  

# Each operation updates the vault and emits an event.  

# Deposits automatically check if the user qualifies for an NFT.

# 

# \*\*NFT Reward System\*\*  

# When a user’s total balance exceeds the defined USD threshold, the contract interacts with an external NFT contract to mint a reward NFT.

# 

# \*\*Price Feed Integration\*\*  

# The contract uses Chainlink’s ETH/USD feed to determine the real-time conversion rate between ETH and USD.

# 

# ---

# 

# \## 📊 Public Information

# 

# The contract provides public view functions for checking user balances, operation counts, the latest Chainlink price, and the contract’s total holdings.

# 

# ---

# 

# \## 🧰 Dependencies

# 

# | Library | Purpose |

# |----------|----------|

# | OpenZeppelin AccessControl | Role-based access permissions. |

# | OpenZeppelin IERC20 | ERC20 interface for USDC operations. |

# | Chainlink AggregatorV3Interface | ETH/USD price feed integration. |

# | AccessControlContract | NFT minting logic and role management. |

# 

# ---

# 

# \## 🧪 Example Flow

# 

# 1\. A user deposits ETH. The contract updates their vault and checks the price feed.  

# 2\. The user deposits USDC, and the system tracks the equivalent value.  

# 3\. Withdrawals can be performed in ETH or USDC, with security caps enforced.  

# 4\. If the user’s total value surpasses the NFT threshold, an NFT is minted.  

# 

# ---

# 

# \## 🧾 Events

# 

# The contract emits events for every deposit, withdrawal, and NFT minting action, allowing full on-chain traceability of operations.

# 

# ---

# 

# \## ⚠️ Notes \& Limitations

# 

# \- Global counters remain checked to prevent overflow.  

# \- Unchecked arithmetic is only applied to safe per-user operations.  

# \- Reentrancy lock implemented manually for full control.  

# 

# ---

# 

# \## 🧑‍💻 Developer Notes

# 

# \- Solidity version: greater than 0.8.29  

# \- Uses custom errors, immutable variables, and gas-optimized operations.  

# \- Designed for modularity, security, and integration with external DeFi systems.  

# 

# ---

# 

# \## 📜 License

# 

# MIT License © 2025  

# Developed by \*\*Kipu Labs\*\* — for educational and experimental DeFi research.



