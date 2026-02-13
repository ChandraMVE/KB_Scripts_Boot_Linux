#!/bin/sh

# ================================
# GPIO Numbers
# ================================
AMBER_GPIO=175   # GPIO6_15 Amber PASS
RED_GPIO=176     # GPIO6_16 Red FAIL

# ================================
# Export GPIO if not already done
# ================================
export_gpio() {
    GPIO=$1
    if [ ! -d /sys/class/gpio/gpio$GPIO ]; then
        echo $GPIO > /sys/class/gpio/export
        echo out > /sys/class/gpio/gpio$GPIO/direction
    fi
}

# ================================
# LED ON  (Active Low)
# ================================
led_on() {
    GPIO=$1
    echo 0 > /sys/class/gpio/gpio$GPIO/value
}

# ================================
# LED OFF (Active Low)
# ================================
led_off() {
    GPIO=$1
    echo 1 > /sys/class/gpio/gpio$GPIO/value
}

# ================================
# Blink BOTH LEDs at 500ms
# ================================
blink_leds() {
    echo "Blinking BOTH LEDs at 500ms rate..."

    while true; do
        # ON both
        led_on $AMBER_GPIO
        led_on $RED_GPIO
        sleep 0.1

        # OFF both
        led_off $AMBER_GPIO
        led_off $RED_GPIO
        sleep 0.1
    done
}

# ================================
# Main Control
# ================================
# Export both GPIOs always
export_gpio $AMBER_GPIO
export_gpio $RED_GPIO
case "$1" in
    amber_on)
        led_on $AMBER_GPIO
        led_off $RED_GPIO
        echo "Amber LED ON"
        ;;

    amber_off)
        led_off $AMBER_GPIO
        echo "Amber LED OFF"
        ;;

    blink_leds)
	blink_leds
        ;;

    red_on)
        led_on $RED_GPIO
        led_off $AMBER_GPIO
        echo "Red LED ON"
        ;;

    red_off)
        led_off $RED_GPIO
        echo "Red LED OFF"
        ;;

    *)
        echo "Usage:"
        echo "  $0 amber_on"
        echo "  $0 amber_off"
        echo "  $0 blink_leds"
        echo "  $0 red_on"
        echo "  $0 red_off"
        exit 1
        ;;
esac
