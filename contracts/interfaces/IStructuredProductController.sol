// SPDX-License-Identifier: MIT
pragma solidity >=0.4.23 <0.9.0;

interface IStructuredProductController {

/**
     * Creates a SetToken smart contract and registers the SetToken with the controller. The SetTokens are composed
     * of positions that are instantiated as DEFAULT (positionState = 0) state.
     *
     * @param _components             List of addresses of components for initial Positions
     * @param _units                  List of units. Each unit is the # of components per 10^18 of a SetToken
     * @param _modules                List of modules to enable. All modules must be approved by the Controller
     * @param _manager                Address of the manager
     * @param _name                   Name of the SetToken
     * @param _symbol                 Symbol of the SetToken
     * @return address                Address of the newly created SetToken
     */
    function create(
        address[] memory _components,
        int256[] memory _units,
        address[] memory _modules,
        address _manager,
        string memory _name,
        string memory _symbol
    )
        external
        returns (address);


}