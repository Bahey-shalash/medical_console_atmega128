[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Build: Simulator](https://img.shields.io/badge/Build-Simulator-blue.svg)](#)  [![MCU: ATmega128L](https://img.shields.io/badge/MCU-ATmega128L-orange.svg)](#)  [![Language: Assembly](https://img.shields.io/badge/Language-ASM-red.svg)](#)  [![Sensors: DS18B20](https://img.shields.io/badge/Sensors-DS18B20-green.svg)](#)  [![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](#) 
# Medical Console Prototype

This is a **pre-prototype** developed for the EE208 (Spring 2025) [EE208-MICRO210_ESP-2025-v1.1-3.pdf](https://github.com/user-attachments/files/20438062/EE208-MICRO210_ESP-2025-v1.1-3.pdf). The goal is to create a user-friendly medical console for doctors working with autistic children, where vital signs are measured unobtrusively during play. While the current implementation only includes a DS18B20 temperature sensor, the design can be extended to other sensors (e.g., heart rate, oxygen saturation).


## Features

* **Finite State Machine** driven interface with Home, Game 1 (Snake), Game 2, Game 3, and isolated Doctor mode
* **Temperature Monitoring** via DS18B20 1-Wire sensor
* **8×8 RGB LED Matrix** for visual feedback (games & status indicators)
* **Rotary Encoder & Buttons** for intuitive navigation
* **Background Vitals Measurement** while the child plays, making doctor visits less intimidating

## Usage

1. Connect the DS18B20 temperature sensor to the designated data pin. port B
2. Power on the ATmega128L @ 4 MHz board.
3. Use the rotary encoder and buttons to navigate between modes. port E
4. The temperature is periodically measured in the background and displayed on the Doctor screen.
5. LED strip (built in the stk300) port F, they indicate each sampling of the tempreture
<img width="430" alt="Screenshot 2025-05-26 at 10 57 29 AM" src="https://github.com/user-attachments/assets/3cde2b62-871b-43f3-a89b-53cd64ef0fc9" />
<img width="452" alt="Screenshot 2025-05-26 at 10 58 30 AM" src="https://github.com/user-attachments/assets/1b7eac08-b37f-4022-9e53-f2ce01cd983e" />

## File Structure

* `main.asm` – System initialization and state dispatcher
* `home_state.asm` – Home screen and temperature display
* `snake_state.asm` – Classic Snake game implementation
* `game2_state.asm` & `game3_state.asm` – Placeholder game states
* `doctor_state.asm` – Diagnostic/Doctor mode
* `wire1.asm` – DS18B20 1-Wire driver
* `ws2812_driver.asm` & `ws2812_helpers.asm` – WS2812B LED matrix driver
* `encoder.asm`, `lcd.asm`, `printf.asm`, `macros.asm` – Utility libraries

## Contributing

Contributions are welcome! If you extend the sensor suite (e.g., heart rate, SpO₂) or improve the games/interface, please submit a pull request.

## Contributions

* Code by **Bahey Shalash**
* Project report & video filming assistance by **Ramzy Rafla**

## Images

![IMG_1539](https://github.com/user-attachments/assets/23c3a513-8f71-467c-b11d-50dd1ee32848)

![IMG_1540](https://github.com/user-attachments/assets/2d0c2b80-7f7a-4012-a5be-e3e1adf919bb)


![IMG_1541](https://github.com/user-attachments/assets/2b0b44d2-7d7b-464b-9d8a-cee5d30a41a8)

![snake](https://github.com/user-attachments/assets/dcebf076-6526-4e16-878c-279b97e84e3d)




https://github.com/user-attachments/assets/da5c4081-875a-4d4d-93f4-4a6e6261ba07

## License

This project is licensed under the [MIT License](LICENSE).
