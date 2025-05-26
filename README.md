# Medical Console Prototype

This is a **pre-prototype** developed for the EE208 (Spring 2025) [EE208-MICRO210_ESP-2025-v1.1-3.pdf](https://github.com/user-attachments/files/20438062/EE208-MICRO210_ESP-2025-v1.1-3.pdf). The goal is to create a user-friendly medical console for doctors working with autistic children, where vital signs are measured unobtrusively during play. While the current implementation only includes a DS18B20 temperature sensor, the design can be extended to other sensors (e.g., heart rate, oxygen saturation).


## Features

* **Finite State Machine** driven interface with Home, Game 1 (Snake), Game 2, Game 3, and Doctor modes
* **Temperature Monitoring** via DS18B20 1-Wire sensor
* **8×8 RGB LED Matrix** for visual feedback (games & status indicators)
* **Rotary Encoder & Buttons** for intuitive navigation
* **Background Vitals Measurement** while the child plays, making doctor visits less intimidating

## Usage

1. Connect the DS18B20 temperature sensor to the designated data pin. port B
2. Power on the ATmega128L @ 4 MHz board.
3. Use the rotary encoder and buttons to navigate between modes. port E
4. The temperature is periodically measured in the background and displayed on the Home screen.
5. LED strip (built in the stk300) port F, they indicate each sampling of the tempreture

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


