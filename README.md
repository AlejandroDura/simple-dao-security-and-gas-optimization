# **SimpleDAO Security & Gas Optimizations audit**

## 📌 Overview

This repository contains a security and gas optimization audit from a Solidity smart contract SimpleDAO project.

The smart contract target is SimpleDAO.sol. In order to make things as clear as posible we created both versions of this smart contract: SimpleDAO_Original.sol and SimpleDAO.sol. The SimpleDAO_Original.sol is the V1 version, and the SimpleDAO.sol is the V2 version. During the security and gas report audits we reference these files as V1 and V2 versions respectively to identify them. The V1 version is the non audited, vulnerable and not optimized 
version. The V2 version is the secured and audited one. It contains all new improvements, security solutions and gas optimizations.

You will see that SimpleDAO_Original.sol (V1 version) contract has a single file including all of its code in it. Then the Simple_DAO.sol (V2 version), which has a completely new architecture based on modularization usign various
abstract contracts.

The V2 version, has a new architecture because of all these new security improvements introduced. We could place all the code inside the same contract, but this is not a good practice beacuse of readability and scalabiliy concerns. Adopting this new V2 architecture we will be able to extend our code with new changes without touching too much the base code. Additionally, we added the SimpleDAO_Intermediate.sol version, which includes all the new V2 enhancements inside the same contract. This is only to show how it looks if we add all the new code inside a single contract. It is not recommended to do that because we are mixing responsabilities that can be divided in different pieces. This version is just an example or a guide to build the V2 version.

So, this project has differents goals:
- Secure vulnerabilities and code.
- Optimize gas consumptions as much as posible.
- Refactor V1 version to introduce these new changes in an organized way and to facilitate new future changes.
- Implement best Solidity programming practices such as documentation, variable visibility, CEI patterns, etc...


## 🛠 Tech Stack

- Solidity ^0.8.13
- Foundry 
- Forge
- OpenZeppelin

## 📂 Project Structure

**- src/     ->** Here you can find the proyect contracts. They are divided in v1, v2 and aux folders. The **v1** folder contains all contracts related to V1 version. The **v2** folder contains all contracts related to V2 version. The **aux** folder contains axuliar contracts to test some functionalities of both V1 and V2 version. In the src/ root you will find the SimpleDAO_Intermediate version mentioned before. Remember, this version is only a guide to craft V2.

**- test/     ->** Here you can find the tests performed to the contracts. These tests are divided in tree folders: The **gas** folder where you can find the tests used to measure gas consumptions of both versions. The **security** folder where you can find the tests used to prove the vulnerabilities and to test if they are solved. Finally, the **unit** folder where you can find a unit test performed to each function of V2 version.

**- audits/   ->**  The audits folder contains both PDF reports: The SimpleDAO security audit report and the SimpleDAO gas consumptions report.

## 🔍 Security Findings

Various vulnerabilities and problems were detected:

- Reentrancy.
- Missing target validation.
- Voting power transfer.
- Missing quorum.
- State bloat attack or storage griefing.

## ⛽ Gas Optimization

Some gas improvements were made:

- Variable length optimization.
- Struct variable packaging.
- String and byte chains optimization.

## 🚀 How to Run

### Install Foundry

To install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Update Foundry to the latest version:

```bash
foundryup
```

### Install the project

Install project:

```bash
git clone https://github.com/AlejandroDura/simple-dao-security-and-gas-optimization.git
```

Then cd to the project folder:

```bash
cd simple-dao-security-and-gas-optimization/
```

### Build the project

```bash
forge build
```

### Run tests

```bash
forge test
```

## 📄 Audit Reports

As we said before, they can be found in /audits folder:

**- SimpleDAO Gas Report.pdf ->** The gas report audit and the gas consumption improvements.

**- SimpleDAO Security Audit Report.pdf ->** The security audit and the secure improvements. Also includes an explanation about the V2 architectural refactoring.

## 🎯 Learning Objectives

- Deep understanding about how things works at low level.
- Secure programming practices.
- Secure mindset.
- Security concerns.
- Knowledge about Solidity smart contract vulnerabilities (reentrancy, access control...).
- Mixture of scalability and architectural practices, ensuring at the same time security.
- Knowledge about Solidity compiler, bytecode, opcodes, memory, storage and gas consumptions.
- Solidity best practices.
- Writing reports.