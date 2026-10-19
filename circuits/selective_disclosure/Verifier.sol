// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract Groth16Verifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 17329766417869852656944951854833084047575941728782971085232198765739879825382;
    uint256 constant alphay  = 19036172211675799983618271931667704946380430662573609718079617727227302613072;
    uint256 constant betax1  = 8710222804890236897794966409409189053380693873113897177087465913445096813958;
    uint256 constant betax2  = 20954461320083061448957576453131566139828808884790530255020154239042513650709;
    uint256 constant betay1  = 3913439284855698147544145691453365175299201511701484846342401321010163038405;
    uint256 constant betay2  = 7458547741422532686824292722575210400471736396583292171427500735476252909000;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 19597383296861278004696072399700810176717753770156866351842837610264016483994;
    uint256 constant deltax2 = 4427119002023470407733850192602873122122894479035490888554290279482647776183;
    uint256 constant deltay1 = 12386161040585552300723267116724448066102764458042894005629496619192342104807;
    uint256 constant deltay2 = 11991974974985867911153888519921017296723008220793277380215360527061431301388;

    
    uint256 constant IC0x = 17507829209323009886240373106072346499615109557078363376388315902372065333693;
    uint256 constant IC0y = 5265378496634989886318495939192937303579726702726148743072642051825065373129;
    
    uint256 constant IC1x = 11101784049274343546413685167024918879760162826309657584707849966353511441502;
    uint256 constant IC1y = 7721657786780106363899403687876154821257100835524964480704963646858965949322;
    
    uint256 constant IC2x = 4807140518994341882291454452434512176389935671411589916418076043195450175378;
    uint256 constant IC2y = 10134771280572696502202311329002640108806192933974534000155556080084544661462;
    
    uint256 constant IC3x = 9230704925722795330396059828702446627901295171128132803540177439010991567747;
    uint256 constant IC3y = 17978158881782322973636552131649182087440043016192261944825532554379865107730;
    
    uint256 constant IC4x = 10938909016447812786526998585105306335825561031374812253559825026087556210914;
    uint256 constant IC4y = 8549785992780285337149288151028309468111110078991403016828368917229431890215;
    
    uint256 constant IC5x = 6047492726751061770678740070279763677357776144221922214251796381813819606240;
    uint256 constant IC5y = 12655340068113656041328250425450585988959168775894223073394575159318251246276;
    
    uint256 constant IC6x = 12705169753722581908684469646855655577180848801601065301290740973593298457750;
    uint256 constant IC6y = 19152958060837989344287731060852221782244081170301319205959596884050636196461;
    
    uint256 constant IC7x = 5022421816512467613655887700223755347234782883005285533952662595852956264043;
    uint256 constant IC7y = 17431309117504803110629108629333789635844795567823178500097449023902461196897;
    
    uint256 constant IC8x = 5886914523422411115545993031501865688723708779346337129052181896452258668930;
    uint256 constant IC8y = 19321474308434400542119947653340195189163109070857512393278164244364746806457;
    
    uint256 constant IC9x = 12693408468635132963162550382443972646811262951894030639660193526826019219731;
    uint256 constant IC9y = 5580725933590104998831232663079747837534256452227345583833247745893292926064;
    
    uint256 constant IC10x = 13809960495371024816736648066020223611107823844894378124292274495104258597049;
    uint256 constant IC10y = 12571711448640694213889497352288808171309776457933041837676343611049704457280;
    
    uint256 constant IC11x = 9841661639183731436478069536328778189584252394901382726548992587842711908507;
    uint256 constant IC11y = 17165863291022598120330048155287012643760953648294911835011017479699839959103;
    
    uint256 constant IC12x = 17883642017967626550957212648728670122146314029373223002470986912756913264468;
    uint256 constant IC12y = 905833149548438188899586729014102195939681731414856555117790599478686100384;
    
    uint256 constant IC13x = 20251929544753105560483451913967266933245530535995697927964587109223430115191;
    uint256 constant IC13y = 6993105242198138823245081895863447429921293927072249947197501830716404824166;
    
    uint256 constant IC14x = 8451645763480777857309594772259222267703132430621201432964940964080877841988;
    uint256 constant IC14y = 5733183670751797717739853947733324638782510410467148783383820851666790530933;
    
    uint256 constant IC15x = 10232827428080490848626545316705546174338667227168326435778136356627443699708;
    uint256 constant IC15y = 19102682160261352231636075707507509633139729877800347620370619467840640285675;
    
    uint256 constant IC16x = 8375575072855549331776546224369018304607188693044649009823155825077127938689;
    uint256 constant IC16y = 9005782712291145146392665241848476438932702782381145170119018329998085500859;
    
    uint256 constant IC17x = 1703457297361639775931241422102147532731765279442435409226044477904191253390;
    uint256 constant IC17y = 14688452166574519104441541605741768359884660311323343676746405549270909373216;
    
    uint256 constant IC18x = 7847687846201478276669812960150476326917661740274327015224144702380426272599;
    uint256 constant IC18y = 7289125634975417984132873569214757888886184122792548035525835863206364274696;
    
    uint256 constant IC19x = 16389240312654780480236338510004273727468729072472159764948989523153136652232;
    uint256 constant IC19y = 15227619201755905440809539893562211746487557358128002975779074303579229428794;
    
    uint256 constant IC20x = 9599765067876972664108179286164744052103252803262764805602538524833546387533;
    uint256 constant IC20y = 13708398248425817615146195899752166786342351216998301286313941442662706964328;
    
    uint256 constant IC21x = 1138425391478182228743959323790202897579471199676035587027437462968069369986;
    uint256 constant IC21y = 10682349329419969380448842000969650751079782882898082586996911405905521498463;
    
    uint256 constant IC22x = 20710734988118662387107579329711488834456119488693328713153500468099837275188;
    uint256 constant IC22y = 3120625277716511173946780245318540894235524287452997452935202963408462925341;
    
    uint256 constant IC23x = 8503417502681720850586769152973463994641180749076342130960291802747313745000;
    uint256 constant IC23y = 11579081857277158268818222012335353347744700498753679667986321112447195131557;
    
    uint256 constant IC24x = 20982894518059072808298273674055500093380111546025860480143640547583013587586;
    uint256 constant IC24y = 17069521418255329682571005135841332204619294216165914115760892959823983158081;
    
    uint256 constant IC25x = 18106542552310873399919310278683183385832566553065695300601733762337047998918;
    uint256 constant IC25y = 14363915270488368785234108576355071400097411841173384822785696151581448927742;
    
    uint256 constant IC26x = 1530083954586392031106654596396041062463950672705088076763649564237155372948;
    uint256 constant IC26y = 6322081736781082662731379944319795489631179161154856266143897573615885475155;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[26] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                
                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))
                
                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))
                
                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))
                
                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))
                
                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            
            checkField(calldataload(add(_pubSignals, 352)))
            
            checkField(calldataload(add(_pubSignals, 384)))
            
            checkField(calldataload(add(_pubSignals, 416)))
            
            checkField(calldataload(add(_pubSignals, 448)))
            
            checkField(calldataload(add(_pubSignals, 480)))
            
            checkField(calldataload(add(_pubSignals, 512)))
            
            checkField(calldataload(add(_pubSignals, 544)))
            
            checkField(calldataload(add(_pubSignals, 576)))
            
            checkField(calldataload(add(_pubSignals, 608)))
            
            checkField(calldataload(add(_pubSignals, 640)))
            
            checkField(calldataload(add(_pubSignals, 672)))
            
            checkField(calldataload(add(_pubSignals, 704)))
            
            checkField(calldataload(add(_pubSignals, 736)))
            
            checkField(calldataload(add(_pubSignals, 768)))
            
            checkField(calldataload(add(_pubSignals, 800)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
