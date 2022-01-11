// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IWETH9.sol";
import "./WETH9.sol";
import "./Uniswap.sol";

contract TestContract is ReentrancyGuard {
    using SafeERC20 for IERC20;
    address payable public immutable weth;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // assume mannet hardfork

    constructor(address payable _weth) {
        weth = _weth;
    }

    mapping(address => mapping(address => uint256)) public _balances;
    mapping(address => uint256) public _balancesEth;

    function deposit(address asset, uint256 amount) external nonReentrant {
        _balances[asset][msg.sender] += amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount) external nonReentrant {
        require(_balances[asset][msg.sender] >= amount, "Not enough amount");
        _balances[asset][msg.sender] -= amount;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function depositEth() public payable nonReentrant {
        _balancesEth[msg.sender] += msg.value;
    }

    function wrap(uint256 amount) public payable nonReentrant {
        require(_balancesEth[msg.sender] >= amount, "Not enough ETH");

        _balancesEth[msg.sender] -= amount;
        _balances[weth][msg.sender] += amount;
        IWETH9(weth).deposit{value: amount}();
    }

    function withdrawEth(uint256 amount) external nonReentrant {
        require(_balancesEth[msg.sender] >= amount, "Not enough ETH");

        _balancesEth[msg.sender] -= amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function unwrap(uint256 amount) public payable nonReentrant {
        require(_balances[weth][msg.sender] >= amount, "Not enough WETH");

        _balances[weth][msg.sender] -= amount;
        _balancesEth[msg.sender] += amount;
        IWETH9(weth).withdraw(amount);
    }

    receive() external payable {
        if (msg.sender != weth) {
            depositEth();
        }
    }

    // not deployed feature
    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _to
    ) external returns (uint256) {
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == weth || _tokenOut == weth) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = weth;
            path[2] = _tokenOut;
        }

        uint256[] memory amounts;
        amounts = IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            _to,
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    function getAmountOutMin(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256) {
        address[] memory path;
        if (_tokenIn == weth || _tokenOut == weth) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = weth;
            path[2] = _tokenOut;
        }

        // same length as path
        uint256[] memory amountOutMins = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(_amountIn, path);

        return amountOutMins[path.length - 1];
    }
}
