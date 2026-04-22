# system_info.py
import argparse
import platform
import psutil
import socket
import os

def get_ip():
    return socket.gethostbyname(socket.gethostname())

parser = argparse.ArgumentParser()
parser.add_argument("-d", action="store_true")
parser.add_argument("-m", action="store_true")
parser.add_argument("-c", action="store_true")
parser.add_argument("-u", action="store_true")
parser.add_argument("-l", action="store_true")
parser.add_argument("-i", action="store_true")

args = parser.parse_args()

if args.d:
    print("Distro:", platform.platform())

if args.m:
    mem = psutil.virtual_memory()
    print(f"Memory -> Total: {mem.total}, Used: {mem.used}, Free: {mem.available}")

if args.c:
    print("CPU:", platform.processor())
    print("Cores:", psutil.cpu_count())
    print("Speed:", psutil.cpu_freq())

if args.u:
    print("User:", os.getlogin())

if args.l:
    print("Load Avg:", os.getloadavg())

if args.i:
    print("IP:", get_ip())
    