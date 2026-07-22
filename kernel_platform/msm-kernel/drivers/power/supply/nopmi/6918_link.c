#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/init.h>

static int __init i2c_write_input_limit_volt_6918(void) {
    struct i2c_adapter *adapter;
    struct i2c_msg msg;
    int ret;
    u8 buf[2] = {0x06, 0xEF};
    adapter = i2c_get_adapter(1); // I2C1
    if (!adapter) {
        printk(KERN_ERR "Failed to get I2C adapter\n");
        return -ENODEV;
    }
    msg.addr = 0x6B;
    msg.flags = 0;
    msg.len = 2;
    msg.buf = buf;
    ret = i2c_transfer(adapter, &msg, 1);
    if (ret != 1) {
    printk(KERN_ERR "I2C transfer failed: %d\n", ret);
    i2c_put_adapter(adapter);
    return -EIO;
    }
    i2c_put_adapter(adapter);
    printk(KERN_INFO "I2C transfer successful\n");
    return 0;
}

static void __exit i2c_write_exit(void) {
    printk(KERN_INFO "end 6918 set\n");
}

module_init(i2c_write_input_limit_volt_6918);
module_exit(i2c_write_exit);