// SPDX-License-Identifier: MIT
pragma solidity >=0.4.23 <0.9.0;

/* ========== Requirements and Imports ========== 
================================================
*/

import "./TransferHelper.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/IStructuredProductController.sol";

contract ProductManager is Ownable, ReentrancyGuard {
    // using SafeMath for uint256;

    /* ========== State Variables ========== 
    ================================================
    */

    //Addresses:
    address private constant _ASSET_CREATOR =
        0xeF72D3278dC3Eba6Dc2614965308d1435FFd748a;

    //Interfaces //
    IStructuredProductController public constant asset_creator =
        IStructuredProductController(_ASSET_CREATOR);

    /* ========== Events ========== 
    ================================================
    */

    /* ========== Create Structured Product ========== 
    ================================================
    */

    function createStructuredProduct(
        address[] memory _components,
        int256[] memory _units,
        address[] memory _modules,
        address _manager,
        string memory _name,
        string memory _symbol
    ) external onlyOwner returns (address _structuredProductAddress) {
        _structuredProductAddress = asset_creator.create(
            _components,
            _units,
            _modules,
            _manager,
            _name,
            _symbol
        );
    }
}
