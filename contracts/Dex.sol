// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Dex {
    
    constructor() {
        admin = msg.sender;
    }

    struct Token {
        string ticker; //ticker: DAI, ETH...
        address tokenAddress;
    }
    string[] public tokenList;
    mapping(string => Token) public tokens;

    address public admin;

    mapping(address => mapping(string => uint)) public balances;

    string constant DAI = "DAI";

    

    // Vamos a crear las funciones de agregado de tokens dentro del dex

    function addToken(string memory ticker, address tokenAddress) external onlyAdmin() { 
        tokens[ticker] = Token(ticker, tokenAddress);
        tokenList.push(ticker);
    }

    function removeToken(string memory ticker) external onlyAdmin() { 
        tokens[ticker] = Token('', address(0));
    }


    // Creamos las funciones para agregar y quitar liquidez.

    function deposit(uint _amount, string memory ticker) external tokenExist(ticker) {
        IERC20(tokens[ticker].tokenAddress).transferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][ticker] += _amount;
    }


    function withdraw(uint _amount, string memory ticker) external tokenExist(ticker) {
        require(balances[msg.sender][ticker] >= _amount, 'Not enough tokens');
        balances[msg.sender][ticker] -= _amount;
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender, _amount);
    }

    modifier tokenExist(string memory ticker) {
        require(tokens[ticker].tokenAddress != address(0), 'token not approved');
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Only admin can interact.');
        _;
    } 


    // Creación de las órdenes límite

    enum Side {
        BUY,
        SELL
    }
    
    struct Order {
        uint id;
        address trader;
        Side side;
        string ticker;
        uint amount;
        uint filled;
        uint price;
        uint date;
    }

    mapping(string => mapping(uint => Order[])) public orderBook;
    uint public nextOrderId;


    function createLimitOrder(string memory ticker, uint amount, uint price, Side side) external tokenExist(ticker) {
        if (side == Side.SELL) {
            // Si es una venta, vamos a comprobar si el usuario tiene tockens suficientes
            require(balances[msg.sender][ticker] >= amount, 'Balance too low.');
        } else {
            require(balances[msg.sender][DAI] >= amount * price, 'DAI balance too low.');
        }

        // Vamos a obtener la lista de órdenes.
        Order[] storage orders = orderBook[ticker][uint(side)]; //uint side da la posición del enum.
        orders.push(Order(nextOrderId, msg.sender, side, ticker, amount, 0, price, block.timestamp));
        // Vamos a tener que sortear el orderBook por el precio, de mayor a menor, usando un algoritmo
        uint i = orders.length - 1;
        while(i > 0) {
            if(side == Side.BUY && orders[i - 1].price > orders[i].price) {
                break;
            }
            if(side == Side.SELL && orders[i - 1].price < orders[i].price) {
                break;
            }
            Order memory order = orders[i-1];
            orders[i-1] = orders[i];
            orders[i] = order;
            i--;
            // Continuamos hasta que rompa en los ifs, o hasta que se acabe el while
        }
        nextOrderId++;
    }

    // Vamos a crear un market order: Cuando quieres vender una ctivo a cualquier precio

    event NewTrade(
        uint trade,
        uint orderId,
        string indexed ticker,
        address indexed trader1,
        address indexed trader2,
        uint amount,
        uint price,
        uint date
    );

    uint nextTradeId;

    function createMarketOrder(string memory ticker, uint amount, Side side) external tokenExist(ticker) {
        if(side == Side.SELL) {
            require(balances[msg.sender][ticker] >= amount, 'Balance too low.');
        }
        Order[] storage orders = orderBook[ticker][uint(side == Side.BUY ? Side.SELL : Side.BUY)];
        uint i;
        uint remaining = amount;

        // Iteramos las órdenes hasta completarlas todas
        while(i < orders.length && remaining > 0) {
            // Obtenemos cuánto DAI hay disponible
            uint available = orders[i].amount - orders[i].filled;
            uint matched = (remaining > available) ? available : remaining;
            remaining -= matched;
            orders[i].filled += matched;
            emit NewTrade(nextTradeId, orders[i].id, ticker, orders[i].trader, msg.sender, matched, orders[i].price, block.timestamp);
            if(side == Side.SELL) {
                balances[msg.sender][ticker] -= matched;
                balances[msg.sender][DAI] += matched * orders[i].price;
                balances[orders[i].trader][ticker] += matched;
                balances[orders[i].trader][DAI] -= matched * orders[i].price;
            } else {
                // Es posible que el comprador no tenga suficiente DAI para comprar
                require(balances[msg.sender][DAI] >= matched * orders[i].price, "Not enough DAI");
                balances[msg.sender][ticker] += matched;
                balances[msg.sender][DAI] -= matched * orders[i].price;
                balances[orders[i].trader][ticker] -= matched;
                balances[orders[i].trader][DAI] += matched * orders[i].price;
            }
            nextTradeId++;
            i++;
        }

        // Ahora, hay que eliminar las órdenes completadas, para optimizar el SC
        i = 0;
        while(i < orders.length && orders[i].filled == orders[i].amount){
            // Hay que mover todas las órdenes a la izquierda y eliminar la última
            for(uint j = i; j < orders.length-1; j++) {
                orders[j] = orders[j+1];
            }
            // Eliminamos el último
            orders.pop(); 
            i++;
        }
    }


    // Finalmente, vamos a crear una función para obtener las órdenes y los tokens

    function getOrders(string memory ticker, Side side) external view returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }

    function getTokens() external view returns(Token[] memory) {
      // Declaramos una lista de tokens
      Token[] memory _tokens = new Token[](tokenList.length);
      for (uint i = 0; i < tokenList.length; i++) {
        _tokens[i] = Token(
          tokens[tokenList[i]].ticker,
          tokens[tokenList[i]].tokenAddress
        );
      }
      return _tokens;
    }

}
 