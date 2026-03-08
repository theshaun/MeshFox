
echo "# Setting default configuration to femtofox..."
PYMC_CONFIG_FILE="$PYMC_CONFIG_DIR/config.yaml"

sed -i "s/^  cs_pin:.*/  cs_pin: 16/" "$PYMC_CONFIG_FILE"
sed -i "s/^  reset_pin:.*/  reset_pin: 25/" "$PYMC_CONFIG_FILE"
sed -i "s/^  busy_pin:.*/  busy_pin: 22/" "$PYMC_CONFIG_FILE"
sed -i "s/^  irq_pin:.*/  irq_pin: 23/" "$PYMC_CONFIG_FILE"
sed -i "s/^  rxen_pin:.*/  rxen_pin: 24/" "$PYMC_CONFIG_FILE"
sed -i "/^  cs_pin:.*/a\\  gpio_chip: 1" "$PYMC_CONFIG_FILE"
sed -i "/^  gpio_chip:.*/a\\  use_gpiod_backend: true" "$PYMC_CONFIG_FILE"

# Hard code low power just incase its a e22 900m33s and we don't want to fry it first load...
sed -i "s/^  tx_power:.*/  tx_power: 1/" "$PYMC_CONFIG_FILE"