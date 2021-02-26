<?php

// Visual format of character table.
// Can be edited before generate assembly commands for SSD1780 display by visual2asm.php.
// Pixels where space characters are, will be off. Any other than space will switch on the pixel.

include "fonttab.php";

$ret =
"; -----------------------------------------------------------
; Assambly font definitions. Generated from font_visual.php.
; These are already in I2C command format. Jump to [ascii*11]
; -----------------------------------------------------------
#ROM

fonttab\n
        ;       Command of action (Write 9 bytes to IIC)
        ;       |   Co=0 (continuous), D/C#=1 (next bytes are data)
        ;       |   |   First (most left) column of character
        ;       |   |   |   Last (most right) column of character
        ;       |   |   |   +-----------------------+   End of action
        ;       |   |   |     (LSB:Top MSB:bottom)  |   |
";
foreach($font_8x8_array as $code => $char){
  $ret .= "        db      $09,$40";
  for($i=0;$i<8;$i++){//oszlopok
    $byte = "";
    for($j=0;$j<8;$j++){//sorok
      if(substr($char[$j],$i,1) != " "){
        $byte.="1";
      } else {
        $byte.="0";
      }
    }
    $ret .= sprintf(",$%02X",bindec(strrev($byte)));
  }
  $ret .= sprintf(",$00 ; '%c' %d = 0x%02X\n",(32<=$code)?$code:32,$code,$code);
}

$ret .= "\nfonttab_len     equ     $-fonttab\n\n";
file_put_contents("fonttab.inc",$ret);

?>
