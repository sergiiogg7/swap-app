// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IV2Router02} from "../../src/interfaces/IV2Router02.sol";
import {SwapApp} from "../../src/SwapApp.sol";

interface IMintable {
    function mint(address to_, uint256 amount_) external;
}

/// @dev ERC20 with open mint.
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }
}

/// @dev Mimics mainnet USDT: no return values and approve must go through zero first.
contract NoReturnToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to_, uint256 amount_) external {
        balanceOf[to_] += amount_;
    }

    function approve(address spender_, uint256 amount_) external {
        require(amount_ == 0 || allowance[msg.sender][spender_] == 0, "approve from non-zero");
        allowance[msg.sender][spender_] = amount_;
    }

    function transfer(address to_, uint256 amount_) external {
        balanceOf[msg.sender] -= amount_;
        balanceOf[to_] += amount_;
    }

    function transferFrom(address from_, address to_, uint256 amount_) external {
        allowance[from_][msg.sender] -= amount_;
        balanceOf[from_] -= amount_;
        balanceOf[to_] += amount_;
    }
}

/// @dev 1:1 router mock that honours the deadline and the minimum output, minting the output token.
contract MockRouter is IV2Router02 {
    using SafeERC20 for IERC20;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(block.timestamp <= deadline, "expired");
        require(amountIn >= amountOutMin, "insufficient output");

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        IMintable(path[path.length - 1]).mint(to, amountIn);

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountIn;
    }
}

/// @dev Token that re-enters SwapApp.swapTokens from inside transferFrom.
contract ReentrantToken is ERC20 {
    SwapApp public app;

    constructor() ERC20("Evil", "EVIL") {}

    function setApp(SwapApp app_) external {
        app = app_;
    }

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool) {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(this);
        app.swapTokens(1, 0, path, type(uint256).max);
        return super.transferFrom(from_, to_, amount_);
    }
}
