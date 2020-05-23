# sci2can

SCI to CAN gateway


## Introduction

This project was developed to receive large data packets from SCI
(RS232 UART without MAX232 line driver) and forward data to CAN
to be available on CAN based tool-chain for analysis purpose.

I decided, this is the perfect moment to get use S08D family, because this
supports faster SCI baud rates than GZ family what I know well.
Therefore I searched my dusty DEMO9S08DZ60 demo board in the cupboard.

![demo9s08dz60](https://github.com/butyi/sci2can/raw/master/pics/demo9s08dz60.jpg)


## Software

Software is simple pure and assembly code. Funny, it is just 454 bytes long.

### Modules

To understand my description below you may need to look at the related part in
[processor reference manual](https://www.nxp.com/docs/en/data-sheet/MC9S08DZ60.pdf).

#### I/O ports

To prevent extra current consumption caused by flying not connected input ports,
all ports shall be configured as output. I have configured ports to low level
output by default.
There are only some exceptions for the used ports, where this default
initialization is not proper. For example inputs pins.
This default initialization is proper for FET and OSCILL_SUPP pins, so there is
no specific code for these pins.

#### Multi-purpose Clock Generator (MCG)

MCG is configured to PEE mode. But this mode can be reached through other modes.
See details in
[AN3499](https://www.nxp.com/docs/en/application-note/AN3499.pdf).
Bus frequency is only 8MHz now, while theoretical maximum is 20MHz.
So here there is improvement potential if software execution is not enough fast.

I have measured bus clock by this code.

`        ldhx    #PTB`

`MAIN`

`        lda     ,x      ; 3 cycles`

`        eor     #PIN3_  ; 2 cycles`

`        sta     ,x      ; 2 cycles`

`        bra     MAIN    ; 3 cycles`

![osc_busclk](https://github.com/butyi/sci2can/raw/master/pics/osc_busclk.png)

Really 8Mhz.

#### Serial Communications Interface (SCI)

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

#### Controller Area Network (CAN)

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
parts can be can be watched on not used uC pins by oscilloscope.
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

### References
 
Regarding assembly commands read
[HCS08RMV1.pdf](https://www.nxp.com/docs/en/reference-manual/HCS08RMV1.pdf).
Now (when I am writing this) it is not available on this link even though
I have downloaded from here some weeks before. Try to search it on the Internet.

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
  - Power supply ( +7V ... +30V )
  - Serial data input line
  - CAN Low
  - CAN High
- Supply power input must support both 12V and 24V systems.
- Supply power reverse polarity protection needed.
- Supply power LED on internal 5V.
- SCI does not need MAX232 driver because there isn't in the transmitter too.
- SCI port must be protected against connect to supply (+30V).
- CAN transceiver is needed.
- CAN Built in terminator resistor is needed.
- Status LED needed with software control.
- Standard BDM port for software download.
- Small board with direct wire connection (not specific connector).

### Printed Circuit Board

PCB was designed on [KiCad](https://kicad-pcb.org/), which is a free
PCB development environment on works also on Linux.
It works well, I really like to use it. I was so satisfied, I have donated the
project through [Linux Foundation.](https://www.linuxfoundation.org/).
I have exported schematic in PDF for those who do not have KiCad installed.

Designed PCB is a small board with size 31x32 mm.
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

PCBs were produced by [SOS PCB Kft.](https://nyakexpressz.hu/). I am satisfied
with quality of production.

![pcb1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb1.jpg)

![pcb2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcb2.jpg)

Next pictures about mounting parts.

![pcbm1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbm1.jpg)

![pcbm2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbm2.jpg)

![pcbm3](https://github.com/butyi/sci2can/raw/master/pics/sci2can_pcbm3.jpg)

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

### Connector

Connector has a 6 pins screw connector for wires. I used what I have at home.
The connector is not necessary to be mounted, wires can be soldered directly
into the holes. It saves some money and size.

### Power supply

Power input starts with D1 diode for reverse polarity protection.
7805 was designed but of course the switching step-down replacement to be
used. That is high efficiency in same size and same pinout.
Search "7805 replacement switching regulator" on Internet.
Unfortunatey what I have damaged on 25V input. Therefore I needed to use a bit
bigger one. This contains MP1584, with maximal input voltage 30V. But my plan
is to use MP4560 instead, which can be used up to 55V.
There are some filter capacitors around. Once is at the microcontroller.
Finally there is the optional power LED (D2). It shows power on state, when
+5V is available.

### BDM port

BDM port is like proposed in datasheet. This matches to USBDM developer
interface which I use. Single pin communication line (BKGD) has external pull
up resistor, even if it is not necessary.
Reset pin has simple external pull up resistor and filter capacitor.
This is only needded for software update.

### SCI input

SCI input is connected to RX pin of SCI1 module. There are serial resistors
for protection against its connection to 24V.
There is 500mW zener diode (D5) against higher than 5V conected to uC pin.
Especially because PTE port has no built in clamp diode to 5V.
R5 serial resistor is to protect zener against too high current.
R4 is needed to decrease the current when input is connected to +30V.
But this is too large for 5V level serial communication. It decreases the
communication line voltage below 2.5V, which is too low, not enough for
communication. This is why C7 is there. For DC this capacitor is line it is not
there. But on high frequency (baud rate) its reactance is about 1kOhm, which
still OK for communication.
Here is a screenshot about shape of SCI signal on the uC pin (RxD1).

![SCI_bits](https://github.com/butyi/sci2can/raw/master/pics/SCI_bits.png)

### CAN output

CAN uses PCA82C251 transceiver (U2). Since there will be point-point connection
on this CAN and other side usually do does not have terminator resistor,
there is built in CAN line terminator resistor (RT1) with 120 Ohm.
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

#### Input

SCI input is also connected to PTA0. It allows to be used as analogue input.
In this case R6 was designed to be used as low side of a voltage divider.
If filter is needed, filter capacitor can be soldered on the top of R7 or D5.

#### Output

Hardware has a low side FET output (Q2). This can switch some external load,
like lamp, buzzer, relay, or similar. It has also a LED (D4) to be visible if
FET is switched on or off.
Gate is pulled down to close FET while port is not yet controlled.
FET was intentionally connected to PTD2, because this pin is timer output port.
This makes output pulse and PWM capable.

OUT port can also be used as input if FET is not mounted but instead a suitable
resistor is mounted between source and gate pins of FET. In this case this
resistor together with R13 is a voltage divider. Filter capacitor (if needed)
can be soldered on the top of R13.
Since FET is connected to timer port, this way timer can be used for
pulse length measurement, frequency measurement or similar.

#### Supply measurement

Since there was enough place on PCB and remained several not used ports,
voltage divider was designed from power supply input (UZ) and connected to
PTA5 analogue measurement capable port. With this parts supply voltage can
be measured by the software and used for any purpose.

#### BDM extra pins

Originally pin 3 and 5 are not used on BDM port. I am planning to develop
bootloader for this controller too for faster and easier software download.
Therefore I have connected Rx and Tx pins of second SCI module (SCI2) to
these two not used BDM pins.
I know that these ports are same with CAN Rx and Tx ports on 32pins package,
but the bootloader will not use CAN and transceiver can be disabled by the
bootloader.

### Box

I have selected this box:

![box](https://github.com/butyi/sci2can/raw/master/pics/box.png)

Simple, cheap, small. Perfect.

Here are pictures about prototype with a different but similar box.

![box1](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box1.jpg)

![box2](https://github.com/butyi/sci2can/raw/master/pics/sci2can_box2.jpg)

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

### Workshop

Finally here is a picture about my workshop corner. :-)

![workshop](https://github.com/butyi/sci2can/raw/master/pics/workshop.jpg)

## License

This is free. You can do anything you want with it.
While I am using Linux, I got so many support from free projects,
I am happy if I can give something for the community.

## Keywords

Motorola, Freescale, NXP, MC68HC9S08DZ60, 68HC9S08DZ60, HC9S08DZ60, MC9S08DZ60,
9S08DZ60, HC9S08DZ48, HC9S08DZ32, HC9S08DZ, 9S08DZ, UART, RS232.

###### 2020 Janos BENCSIK



