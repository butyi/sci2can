# sci2can

SCI to CAN gateway


## Introduction

This project was developed to receive large data packets from SCI
(RS232 UART without MAX232 line driver) and forward data to CAN
to be available on CAN based tool-chain for analysis purpose.

I decided, this is the perfect moment to get use S08D family, because this
supports faster SCI baud rates than GZ family what I know well.
Therefore I searched my dusty DEMO9S08DZ60 demo board in the deep of cupboard.

![demo9s08dz60](https://github.com/butyi/sci2can/raw/master/pics/demo9s08dz60.jpg)


## Software

Software is pure assembly code. Funny, it is just 454 bytes long.

### Modules

To understand my description below you may need to look at the related part in
[processor reference manual](https://www.nxp.com/docs/en/data-sheet/MC9S08DZ60.pdf).

#### Central Processor Unit (S08CPUV3)
 
Regarding assembly commands read
[HCS08RMV1.pdf](https://www.nxp.com/docs/en/reference-manual/HCS08RMV1.pdf).
Now (when I am writing this) it is not available on this link even though
I have downloaded from here some weeks before. I have stored it
[here](https://github.com/butyi/sci2can/raw/master/hw/HCS08RMV1.pdf).

My most often read parts are
- Instruction Set Summary (from page 121)
- Branch summary table on sheet of BRA instruction (page 232)

#### Parallel Input/Output Control

To prevent extra current consumption caused by flying not connected input ports,
all ports shall be configured as output. I have configured ports to low level
output by default.
There are only some exceptions for the used ports, where this default
initialization is not proper. For example inputs pins.
This default initialization is proper for FET and OSCILL_SUPP pins, so there is
no specific code for these pins.

#### Multi-purpose Clock Generator (S08MCGV1)

MCG is configured to PEE mode. But this mode can be reached through other modes.
See details in
[AN3499](https://www.nxp.com/docs/en/application-note/AN3499.pdf).
Bus frequency is only 8MHz now, while theoretical maximum is 20MHz.
So here there is improvement potential if software execution is not enough fast.

I have measured bus clock by this code.

![busclkmeascode](https://github.com/butyi/sci2can/raw/master/pics/busclkmeascode.png)

Really 8 Mhz, because 8 MHz is 125ns, 10 cycle is 1250ns, which can be seen between edges.

![osc_busclk](https://github.com/butyi/sci2can/raw/master/pics/osc_busclk.png)

#### Serial Communications Interface (S08SCIV4)

SCI clock is driven by Bus Clock. Maximal baud rate is Bus Clock divided by 16.
Since my Bus Clock is 8MHz, maximum baud rate is 500k baud. Now I just need
baud 125k in this application. It is enough to enable only RX direction.
Data is coming in burst, many bytes immediately after each other. There is
idle period between data bursts.
I use Rx and Idle interrupts. Rx interrupt stores received byte in RAM buffer.
Idle interrupt is invoked when there is one byte long idle state on the serial
line after active period. I use this event to recognize end of data packet
reception. At this moment CAN transmission can be initiated (if packet looks
good) and prepare SCI to next packet.

#### Freescale Controller Area Network (S08MSCANV1)

Regarding CAN clock it is proposed to use external clock directly. With 4MHz
crystal maximum baud rate is 500k baud. This is enough for my needs.
CAN bit consists of 8 time quanta. Sample point is 75% (6+2 tq).
Only transmission is used. Receive related registers are not initialized.
But Tx interrupt is used. Message preparation is done by interrupt routine.
Transmission is triggered by enable Tx interrupt. Then interrupt will send
all CAN messages one after another. Last message disables the interrupt to
stop the transmission of data burst.
Automatic BufOff recovery is configured, there is no other error handling. 
After CAN module initialization, an info message is sent to CAN. This contains
software identification information, like application identifier, software
revision, build date.

![can_info_message](https://github.com/butyi/sci2can/raw/master/pics/can_info_message.png)

### Main loop

#### Structure

Software does not have any operation system. It is not needed, especially
because there no task in main loop. Everything is executed in interrupt
routines.

#### Initialization

Stack, ports, needed modules are initialized one by one.

#### Main activity

The following procedure is executed cyclically.
First SCI Rx interrupt fills up the RAM buffer with data.
After Idle interrupt is called. If amount of received data is proper,
CAN transmission is initialized by enable CAN Tx interrupt.
Then CAN Tx interrupts will send out all data from RAM buffer to CAN.
Last CAN message disables itself (CAN Tx interrupt).
Additional features of hardware is not handled by software yet.

#### Status LED

Meantime RTC interrupt handles the status LED.
The following codes are visible on LED.
- 0001, Short 25% On flash: There is no SCI communication.
- 0011, Medium 50%-50% On-Off flash: Received SCI bytes are not enough.
- 0111, Long 75% On flash: Data cannot be sent to CAN.
- 1111, Always On: Everything are OK, data is forwarded to CAN properly.

#### CAN message structure

The 96 data bytes are transmitted in 12 messages. The CAN ID is the position of
first byte of message in the SCI buffer multiplied by 8. This means
- ID of first message is zero
- ID of second message is 8*8 = 64 dec = 40hex
- ID of third message is 16*8 = 128 dec = 80hex
- ... and so on.

![can_messages](https://github.com/butyi/sci2can/raw/master/pics/can_messages.png)

#### Debug support

If OSCILL_SUPP is enabled by compiler switch, execution timing of software
parts can be watched on not used uC pins by oscilloscope.
Here are oscilloscope screenshots about software activity.

- Blue is SCI line. Bursts are visible.

![SCI_line](https://github.com/butyi/sci2can/raw/master/pics/sci_line.png)

- Blue is SCI Bursts. Red is PTE0 pin, where rising edge is first Rx interrupt
after the idle period, faling edge is idle interrupt.

![PTE0_SCI_burst](https://github.com/butyi/sci2can/raw/master/pics/pte0_sci_burst.png)

- Blue is SCI Bursts. Red is PTE1 pin, where rising edge is CAN Tx interrupt
enable, faling edge is end of last CAN Tx interrupt.

![PTE1_CAN_burst](https://github.com/butyi/sci2can/raw/master/pics/pte1_can_burst.png)

- Blue is SCI Bursts. Red is PTE4 pin, high during SCI Rx interrupt execution.

![PTE4_SCI_ISR](https://github.com/butyi/sci2can/raw/master/pics/pte4_sci_isr.png)

- Blue is SCI Bursts. Red is PTE5 pin, high during CAN Tx interrupt execution.

![PTE5_CAN_ISR](https://github.com/butyi/sci2can/raw/master/pics/pte5_can_isr.png)

- Blue is PTE3 pin, high during RTC periodic timer interrupt execution.

![PTE3_RTC_ISR](https://github.com/butyi/sci2can/raw/master/pics/pte3_rtc_isr.png)

- Blue is PTE3 pin, length of RTC periodic timer interrupt execution.

![PTE3_RTC_ISR_len](https://github.com/butyi/sci2can/raw/master/pics/pte3_rtc_isr_len.png)

- Blue is PTE4 pin, length of SCI Rx interrupt execution.

![PTE4_SCI_ISR_len](https://github.com/butyi/sci2can/raw/master/pics/pte4_sci_isr_len.png)

- Blue is PTE5 pin, length of CAN Tx interrupt execution.

![PTE5_CAN_ISR_len](https://github.com/butyi/sci2can/raw/master/pics/pte5_can_isr_len.png)

- Blue is SCI Rx bursts, red is CAN Tx burst.

![SCI_and_CAN_burst](https://github.com/butyi/sci2can/raw/master/pics/sci_and_can_burst.png)

- Blue is SCI Rx burst, red is SCI Rx interrupt execution.

![SCI_and_CAN_burst](https://github.com/butyi/sci2can/raw/master/pics/sci_burst_and_isr.png)

### Compile

- Download assembler from [aspisys.com](http://www.aspisys.com/asm8.htm).
  It works on both Linux and Windows.
- Check out the repo
- Run my bash file `./c`.
  Or run `asm8 prg.asm` on Linux, `asm8.exe prg.asm` on Windows.
- prg.s19 is now ready to download.

### Download

Since I haven't written downloader/bootloader for DZ family yet, I use USBDM.

USBDM Hardware interface is cheap. I have bought it for 10€ on Ebay.
Just search "USBDM S08".

![USBDM](https://github.com/butyi/sci2can/raw/master/pics/myusbdm.png)

USBDM has free software tool support for S08 microcontrollers.
You can download it from [here](https://sourceforge.net/projects/usbdm/).
When you install the package, you will have Flash Downloader tools for several
target controllers. Once is for S08 family. This is the window of S08 tool:

![Downloader](https://github.com/butyi/sci2can/raw/master/pics/flash_programmer_window.png)

It is much more comfortable and faster to call the download from command line.
Just run my bash file `./p`.

I got message `Gtk-Message: Failed to load module "canberra-gtk-module"`.
solution was `sudo apt-get install libcanberra-gtk-module`.


## Hardware

After successful operation of software on demo board I decided to design a
specific PCB.

### Requirements

- At least the following connector pins are needed for gateway function:
  - Ground
  - Power supply ( +7V ... +38V )
  - Serial data input line
  - CAN Low
  - CAN High
- Supply power input must support both 12V and 24V systems.
- Supply power reverse polarity protection needed.
- Small power supply dissipation.
- SCI does not need MAX232 driver because there isn't in the transmitter too.
- SCI port must be protected against connect to supply (+38V).
- CAN transceiver is needed.
- CAN Built in terminator resistor is needed.
- Status LED needed with software control.
- Standard BDM port for software download.
- Small board with direct wire connection (not specific connector).

### Microcontroller

I have used MC9S08DZ60. It is enough for such a small project like this.
Assembler, downloader for both Linux and Windows are available for free for this
family. It costs around 1€.
This is my first application with DZ family controller. After finish the
project, and I have to say, I like it! :) It is really better than GZ family.

Refer to
[processor reference manual](https://www.nxp.com/docs/en/data-sheet/MC9S08DZ60.pdf).

### Clock

External Crystal is used for better CAN performances, this is proposed
by uC manufacturer. Passive parts around are also according to datasheet and
similar to development board circuit.
4MHz is enough up to CAN baud rate 500k. For 1Mbaud 8MHz Crystal is needed.
Crystal is now pin type, since via is need anyway, now the pins holes are vias.

### Connector

I used what I have at home. It is two 3 pins screw connector for wires. 

![connector](https://github.com/butyi/sci2can/raw/master/pics/connector.jpg)

The connector is not necessary to be mounted, wires can be soldered directly
into the holes. It saves some money and height.

### Power supply

Power input starts with Ds1 diode for reverse polarity protection.
Same circuit as 7805 replacement was designed on the main board.
Search "7805 replacement switching regulator" on Internet.
It uses ME3116. 1A output, max input voltage is 40V.
I just recognized, transient suppression diode is needed on the input. 
Without this protection the supply could damaged at 24V due sparks during 
switch on. I have choosen SMAJ33A.
There is electrolit capacitor on input voltage.
There are also some filter capacitors on uC supply. 
Once is very close to the microcontroller.

### BDM port

BDM port is like proposed in datasheet. This matches to USBDM developer
interface which I use. Single pin communication line (BKGD) has external pull
up resistor, even if it is not necessary.
Reset pin has simple external pull up resistor and filter capacitor.
This port is only needded for software update.
The connector contains 4 extra pins. Details are below.

### SCI input

SCI input is connected to RX pin of SCI1 module. There are serial resistors
for protection against its connection to 24V.
Next is Ui1 74HC1G125GW as impedance adapter. This provides much higher impedance
input than uC pin.
There is Di2 BZT52C4V7 transient suppressor diode to save further parts of
circuit against high voltage tranzients. 
Especially because PTE port has no built in clamp diode to supply.

When Ui1 is mounted, Ri3 and Ri4 are not needed.
Ri3 and Ri4 are designed when pin is used for normal digit or analogue input. 

Ui1 provides perfect shape and amplitude signal for uC input pin.
Here is a screenshot about shape of SCI signal on the uC pin (RxD1).

![sci_bits](https://github.com/butyi/sci2can/raw/master/pics/sci_bits.png)

### CAN output

CAN uses PCA82C251 transceiver. Since there will be point-point connection
on this CAN and other side usually does not have terminator resistor,
there is built in CAN line terminator resistor (Rc2) with 100 Ohm.
Why not 120ohm? Good question.
To limit number of different parts, I have tried to use 100ohm, 1k, 10k, 100k,
1M resistors and 10nF, 100nF, 1uF, 10uF capacitors as many places as possible.
I could buy these parts by 1€/5000pcs. To store it, the cheapest solution
is to buy empty creme holder box in the pharmacy. :smile:
Turning back to CAN.
CAN hardware supports high baud rates up to 1MBaud, but does not support CANFD. 

### Status LED

Status LED (D3) is connected to PTD2. Level high on pin will switch on the LED.
LED is controlled by the software.

Status LED and power LED are near to each other on the back of PCB
intentionally. Plastic box have a hole where the LEDs are, and PCB is fixed in
the box by glue gun. This glue is usually enough transparent to be LED light
visible outside while it is still dust resistant.

![box3](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box3.jpg)

### Additional features

Board was designed to be usable for other purposes as well, as much as the
board size allows it. Therefore some components and solutions were also
added to hardware. These are not needed for the original function,
but I hope these will be useful for other functions in the future with the same
board. These components are marked by * on the schematic. These are not need to
be mounted for simple gateway function.

#### Inputs

SCI input is also connected to PTA0. It allows to be used as analogue input.
In this case Ri4 was designed to be used as low side of a voltage divider.
If filter is needed, filter capacitor can be soldered on the top of Ri4 or the
zener.
Similar circuit is also available on the other IO pin without pull down resisor.
When IO pins is used as output, input circuit can be used to monitor the output.

#### Outputs

Hardware has two low side FET outputs. These can switch some external loads,
like lamp, buzzer, relay, or similar.
Gate is pulled down to close FET while port is not yet controlled.
FET was intentionally connected to timer output pins, because this makes outputs
pulse and PWM capable.

OUT ports can also be used as timer input if FET is not mounted but instead a
suitable resistor is mounted between source and gate pins of FET. In this case
this resistor together with gate pull down resistor are a voltage divider.
Filter capacitor (if needed) can be soldered on the top of pull down resistor.
Since FETs are connected to timer ports, this way timer can be used for
pulse length measurement, frequency measurement or similar.

#### Supply measurement

Since there was enough place on PCB and remained several not used ports,
voltage divider was designed from power supply input (UZ) and connected to
PTA5 analogue measurement capable port. With this parts supply voltage can
be measured by the software and used for any purpose.

#### BDM extra pins

I have extended the debugger connector by 4 additional pins. These are now
the IIC/SPI pins as preparation to connect some IIC or SPI display to board.
I use it now for a small 0.96 col OLED IIC display.

### Printed Circuit Board

#### Design

PCB was designed on [KiCad](https://kicad-pcb.org/), which is a free
PCB development environment on works also on Linux.
It works well, I really like to use it. I was so satisfied, I have donated the
project through [Linux Foundation.](https://www.linuxfoundation.org/).
I have exported schematic in PDF for those who do not have KiCad installed.
[Here is schematic](https://github.com/butyi/sci2can/raw/master/hw/sci2can_sch.pdf).

Designed PCB is a small board with size 30x30 mm to fit into mentioned box.
Here are some pictures about the board design in KiCad.

![pcbd1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbd1.png)

![pcbd2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbd2.png)

![pcbd3](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbd3.png)

![pcbw1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw1.png)

![pcbw2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw2.png)

![pcbw3](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw3.png)

![pcbw4](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw4.png)

![pcbw5](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw5.png)

![pcbw6](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbw6.png)

#### Production

A-sample PCBs (V1.00) were produced by [SOS PCB Kft.](https://nyakexpressz.hu/).
I was satisfied with quality of production. 

![pcb1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb1.jpg)

![pcb2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb2.jpg)

I have ordered second generation PCB from China with SMD mounting.
Result is sufficient.

![pcb1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb3.jpg)

![pcb2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb4.jpg)

### Mounting

R and C components on the bottom side were mounted by PCB producer.
I have to mount only the up side components by hand.

Note, take care to low resistance of solder paste. Use as less as possible,
and always remove remainings by water.

### Box

Here are pictures about V1.00 prototype.

![box1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box1.jpg)

![box2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box2.jpg)

I have ordered this box for null-series:

![box](https://github.com/butyi/sci2can/raw/master/pics/box.png)

Simple, cheap, small. Perfect.

Here are pictures about V1.02. This series has a 0.96 inch OLED 128x64 pixels
display and two capacitive touch buttons. Suppressor diodes are still mounted
into IO ports, because these were not yet designed on the board.

![box4](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box4.jpg)

![box5](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box5.jpg)

### Costs

- PCB: 3€
- Microcontroller: 2€ (due to I have bought small amount)
- CAN transceiver: 0.25€
- Switching power supply board: 2€
- Screw connector: 0.5€
- Passive components (all together): 1€
- Box: 1€

Most of them are from [ebay](https://www.ebay.com/).
All together 10€ a product without human costs (development, assembly) and
without profit.

## Workshop

Finally here is a picture about my workshop corner. :smile:

![workshop](https://github.com/butyi/sci2can/raw/master/pics/workshop.jpg)

Left side there is russian microscope, right is also russian soldering iron.

## License

This is free. You can do anything you want with it.
While I am using Linux, I got so many support from free projects,
I am happy if I can give something back to the community.

## Notes

I have used `mogrify -resize 640x640\> *` command to downsize the images.
Here `\>` means only shrink larger images and do not enlarge.

## Keywords

Motorola, Freescale, NXP, MC68HC9S08DZ60, 68HC9S08DZ60, HC9S08DZ60, MC9S08DZ60,
9S08DZ60, HC9S08DZ48, HC9S08DZ32, HC9S08DZ, 9S08DZ, UART, RS232.

###### 2020 Janos BENCSIK

