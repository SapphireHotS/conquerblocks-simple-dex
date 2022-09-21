
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX", function () {

  let dexContract;
  let signers = [];
  let daiContract;
  let dotContract;
  let solContract;
  const [DAI, DOT, SOL] = ["DAI", "DOT", "SOL"];
  let trader1;
  let trader2;
  this.beforeEach(async function () {
    signers = await ethers.getSigners();
    trader1 = signers[1];
    trader2 = signers[2];
    
    // Deployeamos el DEX
    const Dex = await ethers.getContractFactory('Dex', {signer: signers[0]});
    const dex = await Dex.deploy();
    dexContract = await dex.deployed();

    // Deployeamos los tokens
    const Dai = await ethers.getContractFactory('Dai', {signer: signers[0]});
    const dai = await Dai.deploy();
    daiContract = await dai.deployed();

    const Dot = await ethers.getContractFactory('Dot', {signer: signers[0]});
    const dot = await Dot.deploy();
    dotContract = await dot.deployed();

    const Sol = await ethers.getContractFactory('Sol', {signer: signers[0]});
    const sol = await Sol.deploy();
    solContract = await sol.deployed();


    // Agregamos los tokens dentro del DEX
    await dexContract.addToken(DAI, daiContract.address);
    await dexContract.addToken(DOT, dotContract.address);
    await dexContract.addToken(SOL, solContract.address);


    // Rellenamos los traders con tokens
    await dai.connect(signers[0]).transfer(trader1.address, ethers.utils.parseUnits("100", "ether"));
    await dai.connect(signers[0]).transfer(trader2.address, ethers.utils.parseUnits("3000", "ether"));

    await dot.connect(signers[0]).transfer(trader1.address, ethers.utils.parseUnits("100", "ether"));
    await dot.connect(signers[0]).transfer(trader2.address, ethers.utils.parseUnits("100", "ether"));

    await sol.connect(signers[0]).transfer(trader1.address, ethers.utils.parseUnits("100", "ether"));
    await sol.connect(signers[0]).transfer(trader2.address, ethers.utils.parseUnits("100", "ether"));


    // Aprobamos los 2 traders para que el DEX pueda usar sus tokens.
    await dai.connect(trader1).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));
    await dai.connect(trader2).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));

    await dot.connect(trader1).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));
    await dot.connect(trader2).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));
    
    await sol.connect(trader1).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));
    await sol.connect(trader2).approve(dexContract.address, ethers.utils.parseUnits("10000", "ether"));
  });



  // FUNCIÓN DEPOSIT
  it("Debería de depositar tokens", async function() {
    let amount = ethers.utils.parseUnits("10", "ether");
    await dexContract.connect(trader1).deposit(amount, DAI);
    let balance = await dexContract.balances(trader1.address, DAI);
    expect(balance).to.equal(amount);
  });

  it("Debería de rechazar el depósito de un token no aprobado", async function() {
    let amount = ethers.utils.parseUnits("10", "ether");
    await expect(dexContract.connect(trader1).deposit(amount, "TOKEN-QUE-NO-EXISTE")).to.be.revertedWith("token not approved");
  });


  // FUNCIÓN WITHDRAW

  it("Debería de sacar los tokens metidos dentro del DEX", async function() {
    let amount = ethers.utils.parseUnits("10", "ether");
    await dexContract.connect(trader1).deposit(amount, DAI);
    let balance = await dexContract.balances(trader1.address, DAI);
    expect(balance).to.equal(amount);

    await dexContract.connect(trader1).withdraw(amount, DAI);
    balance = await dexContract.balances(trader1.address, DAI);
    expect(balance).to.equal(0);
  });

  it("Debería de rechazar sacar un token no aprobado", async function() {
    let amount = ethers.utils.parseUnits("10", "ether");
    await expect(dexContract.connect(trader1).withdraw(amount, "TOKEN-QUE-NO-EXISTE")).to.be.revertedWith("token not approved");
  });


  // FUNCIÓN createLimitOrder

  it("Debería de crear una orden límite", async function() {
    let amount = ethers.utils.parseUnits("10", "ether");
    let price = 1;
    await dexContract.connect(trader1).deposit(amount, DOT);
    await dexContract.connect(trader1).createLimitOrder(DOT, amount, price, 1);
    let buyOrders = await dexContract.getOrders(DOT, 0);
    let sellOrders = await dexContract.getOrders(DOT, 1);

    expect(sellOrders).to.have.lengthOf(1);
    expect(buyOrders).to.have.lengthOf(0);

    expect(sellOrders[0].price).to.equal(price);
    expect(sellOrders[0].amount).to.equal(amount);
    expect(sellOrders[0].ticker).to.equal(DOT);
    expect(sellOrders[0].filled).to.equal(0);
  });


  // FUNCIÓN createMarketOrder

  it("Debería de crear una orden de mercado y ejecutar las órdenes", async function() {
    let amount1 = ethers.utils.parseUnits("10", "ether");
    let amount2 = ethers.utils.parseUnits("20", "ether");
    let amountTotal = ethers.utils.parseUnits("40", "ether");
    let price1 = 20;
    let price2 = 25;
    await dexContract.connect(trader1).deposit(amountTotal, DOT);
    await dexContract.connect(trader1).createLimitOrder(DOT, amount1, price1, 1);
    await dexContract.connect(trader1).createLimitOrder(DOT, amount1, price1, 1);
    await dexContract.connect(trader1).createLimitOrder(DOT, amount2, price2, 1);

    let amountDai = ethers.utils.parseUnits("2000", "ether");
    await dexContract.connect(trader2).deposit(amountDai, DAI);
    await dexContract.connect(trader2).createMarketOrder(DOT, amountTotal, 0);
    let dotAmount = ethers.utils.parseUnits("40", "ether");
    trader2DotBalance = await dexContract.balances(trader2.address, DOT);
    
    let sellOrders = await dexContract.getOrders(DOT, 1);
    expect(trader2DotBalance).to.equal(dotAmount);
    expect(sellOrders).to.have.lengthOf(0);


    expect(sellOrders[0].filled).to.equal(amount2);
    expect(sellOrders[0].amount).to.equal(amount2);


  });

});
