sudo dd if=./input.bin of=/dev/fpga bs=1
sudo dd if=/dev/fpga of=./result.bin bs=1 skip=36 count=16

if cmp -s "result.bin" "expected.bin"; then
    echo "Success: result.bin matches expected.bin."
	rm result.bin
else
    echo "Error: result.bin does not match expected.bin."
	rm result.bin
    exit 1
fi
