### 任务概述

基于一款兼容RV32I的5级顺序流水的处理器RTL代码完成记分牌的设计，以实现指令的乱序执行。

### 基准五级流水处理器介绍

参见Verilog代码。

阅读本文档，完成任务1、2。

### 任务详情

基准处理器RTL代码共包含5站：取指IF、译码ID、执行EX、访存MEM和写回WB。

- 任务1：将执行EX站改成4拍，其中3拍仅是完成指令相关信息的打拍，剩余1拍完成原有EX站的指令执行功能，这4拍中具体哪一拍完成指令执行不做要求。

需要提醒两点：

第一，在基准处理器RTL代码中实现了数据旁路，当把EX站加拍后，如果产生结果的时机与基准代码不同，那么数据旁路的有关逻辑也要修改才能实现正确的数据传递。但是，在修改后的项目中，我们要求**不实现**数据旁路，如果指令A写寄存器Xn，指令B读寄存器Xn，那么总是等指令A将结果写入寄存器文件后，指令B才会被选中去执行，指令B总是从寄存器文件获取Xn的值。

第二，将执行EX站改成4拍，分支指令导致的控制冲突的解决也可能受到影响，代码修改重点关注数据冲突的解决，最终的测试用例不会包含分支指令，所以允许不对分支指令相关的逻辑进行修改，只要能够正确的完成顺序取指即可。

- 任务2：将译码ID站改成两站：流出站IS和读操作数站RO。流出站完成：译码；读取操作数是否就绪信息；读操作数站：读取寄存器类型操作数、生成立即数。根据记分牌的结构和功能，添加两个数据结构：结果寄存器状态表和功能部件状态表。对于进入功能部件状态表的指令，操作数就绪后即可乱序执行。

经过对ID站的改造和EX站的改造，我们的目标处理器共包含9站，依次是IF、IS、RO、EX1、EX2、EX3、EX4、MEM和WB。具体可以参考已有代码，已有代码还设计了结果状态寄存器表，WB站在向寄存器文件写入数据的同时还应该更新结果寄存器状态表。

我们规定执行部件情况为：ADDx1，SUBx1，ANDx1，ORx1，XORx1，LWx1和SWx1，功能部件状态表只需要跟踪这7个部件即可。因此，功能部件状态表包含项：

第一项跟踪ADD部件的状态；第二项跟踪SUB部件的状态；第三项跟踪AND部件的状态；第四项跟踪OR部件的状态；第五项跟踪XOR部件的状态；第六项跟踪LW部件的状态；第七项跟踪SW部件的状态。

因此，功能部件状态表使用3位索引即可，索引0不被使用，使用1~7索引7个执行部件。

结果寄存器状态表共32项（实际上1~31项就足够，因为0号寄存器不可写），每项包含一个字段FU，3位，FU[2:0]含义如下：

- 3'b000：该寄存器已经是ready的，寄存器文件中的值是有效的；
- 3'b001：该寄存器的结果还未被写入寄存器文件，将由ADD部件写该寄存器；
- 3'b010：该寄存器的结果还未被写入寄存器文件，将由SUB部件写该寄存器；
- 3'b011：该寄存器的结果还未被写入寄存器文件，将由AND部件写该寄存器；
- 3'b100：该寄存器的结果还未被写入寄存器文件，将由OR部件写该寄存器；
- 3'b101：该寄存器的结果还未被写入寄存器文件，将由XOR部件写该寄存器；
- 3'b110：该寄存器的结果还未被写入寄存器文件，将由LW部件写该寄存器。

根据以上描述，在基准处理器代码基础上完成记分牌功能的实现。

需要提醒两点：

第一，功能部件状态表中的指令，操作数就绪后就可以被选择进入RO站，如果功能部件状态表中操作数就绪的指令不止一条，那么通常从中选择最老的指令。为了降低实验难度，对选择算法不做要求，只要能够从中选择一个操作数就绪的指令进入RO站即可。这里需要思考一个问题，如果一条指令被选择进入了RO站，在该指令进入写回站前，它还会继续存在于功能部件状态表中，该指令会不会再次被选择进入RO站、导致该指令被重复执行呢？

第二，根据记分牌的功能描述，指令进入WB站的条件是不存在WAR冲突，然而，在我们目前的指令执行流水线等拍、且只有7个执行部件、且执行EX加到4拍的情况下，WAR将不存在。为了降低实验难度，可以不考虑WAR造成的写回停顿，指令执行完就可以直接写回，我们在最终的测试用例中也会避免WAR冲突的出现。

第三，在最终的测试用例中，除了ADD、SUB、AND、OR、XOR、LW和SW外，还会包含ADDI、LUI、AUIPC指令，这些指令用于对整数寄存器赋初值。我们规定这三条指令在ADD部件执行，在功能部件状态表中占用第一项。当然，如果你能够做到这3条指令的执行EX站不加拍，仍然采用原有代码的执行通路完成它们的执行，那么它们可以不进入功能部件状态表。选择一种方案实现即可。

### 测试用例1

```
#####################################################
#test execution latency for ADD, SUB, AND, OR, XOR, LW and SW
#####################################################

.section .text
.global _start
_start:

   # initialize x1 and x2
   li x1, 0x1  #addi x1, x0, 0x1
   li x2, 0x2  #addi x2, x0, 0x2
   # set base address for data access
   la x3, data_seg #auipc, addi
   # remove RAW hazard
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop

main:
   add  x4, x1, x2
   sub  x5, x1, x2
   and  x6, x1, x2
   or     x7, x1, x2
   xor  x8, x1, x2
   lw x9, 0(x3)
   sw x1, 0(x3)
  
_finish:
    # initialize TUBE address
    li x4,   0x13000000 #lui x4, 0x13000
    # send CTRL+D to TUBE to indicate test is finished
    addi x5, x0, 0x4
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    sb x5, 0(x4)
    #dead loop
    #beq x0, x0, _finish
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

.data
data_seg:
.word 0xf3f2f1f0
.word 0xf7f6f5f4
.word 0xfbfaf9f8
.word 0xfffefdfc

```

### 测试用例2

```
#####################################################
#test for scoreboard 
#####################################################

.section .text
.global _start
_start:

   # initialize registers
   li x1, 0x15  #addi x1, x0, 0x15
   li x2, 0x2a  #addi x2, x0,0x2a
   li x4, 0x0    #addi x4, x0, 0x0
   # set base address for data access
   la x3, data_seg #auipc, addi
   # remove RAW hazard
   nop
   nop
   nop
   nop
   nop
   nop
   nop
   nop

main:
   add x4, x1, x2
   sub x5, x1, x4   
   and x6, x1, x4
   or   x7, x1, x2
   xor x8, x1, x2
   lw x5, 0(x3)
   add x9, x5, x2
   sw x9, 0(x3)
   lw x9, 0(x3)
  
_finish:
    # initialize TUBE address
    li x4,   0x13000000 #lui x4, 0x13000
    # send CTRL+D to TUBE to indicate test is finished
    li x5, 0x4 #addi x5, x0, 0x4
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    sb x5, 0(x4)
    #dead loop
    #beq x0, x0, _finish
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop


.data
data_seg:
.word 0xf3f2f1f0
.word 0xf7f6f5f4
.word 0xfbfaf9f8
.word 0xfffefdfc

```