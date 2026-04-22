"""
Automates the execution of configuration commands across multiple Fortinet devices using Netmiko.

This script reads a list of IP addresses and a series of configuration commands from local text files. It iterates through each IP, establishes an SSH connection using the Netmiko library, and applies the specified command set. It is designed specifically for 'fortinet' device types and requires valid credentials to be hardcoded or managed within the device dictionary.

Returns:
The script outputs the configuration results to the console.

Raises:
FileNotFoundError: Raised if 'ips.txt' or 'commands.txt' are not found in the script's root directory.
NetmikoTimeoutException: Potential error if a device is unreachable via the provided IP.
NetmikoAuthenticationException: Potential error if the provided username or password is incorrect.

Guide:
Required pip installs:
pip install netmiko

How to run:

Ensure your root folder contains the script, a file named ips.txt, and a file named commands.txt.

Format ips.txt with one IP address per line.

Format commands.txt with one configuration command per line.

Update the device dictionary in the script with your actual SSH username and password.

Execute the script using: python <script_name>.py.

"""

from netmiko import Netmiko

device = {
    'username': 'yourusernamehere', # Replace with your SSH username
    'password': 'yourpasswordhere', # Replace with your SSH password
    'device_type': 'fortinet',
}

def main():
    with open('ips.txt', 'r') as ip_file:
        ips = ip_file.read().splitlines()

    with open('commands.txt', 'r') as cmd_file:
        commands = cmd_file.read().splitlines()

    for ip in ips:
        print(f"Configuring device with IP: {ip}")
        device['host'] = ip
        net_connect = Netmiko(
            host=device['host'],
            username=device['username'],
            password=device['password'],
            device_type=device['device_type']
        )

        output = net_connect.send_config_set(commands)
        print(output)

        net_connect.disconnect()

if __name__ == "__main__":
    main()
