#Create script, that generates report file with following information:
# - current date and time;
#name of current user;
#internal IP address and hostname;
#external IP address;
#name and version of Linux distribution;
#system uptime;
#information about used and free space in / in GB;
#information about total and free RAM;
#number and frequency of CPU cores

#!/bin/bash/

REPORT_FILE="system_report.txt"

echo "===== SYSTEM REPORT =====" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 1. Current date and time
echo "Date & Time:" >> "$REPORT_FILE"
date >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 2. Current user
echo "Current User:" >> "$REPORT_FILE"
whoami >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 3. Internal IP address and hostname
echo "Hostname:" >> "$REPORT_FILE"
hostname >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "Internal IP Address:" >> "$REPORT_FILE"
hostname -I | awk '{print $1}' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 4. External IP address
echo "External IP Address:" >> "$REPORT_FILE"
curl -s ifconfig.me >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 5. Linux distribution name and version
echo "Linux Distribution:" >> "$REPORT_FILE"
cat /etc/os-release | grep -E "PRETTY_NAME" | cut -d= -f2 | tr -d '"' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 6. System uptime
echo "System Uptime:" >> "$REPORT_FILE"
uptime -p >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 7. Disk usage ( / partition ) in GB
echo "Disk Usage (/ partition):" >> "$REPORT_FILE"
df -h / | awk 'NR==2 {print "Used: "$3", Free: "$4}' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 8. RAM information
echo "Memory (RAM):" >> "$REPORT_FILE"
free -h | awk '/Mem:/ {print "Total: "$2", Free: "$4}' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 9. CPU cores and frequency
echo "CPU Information:" >> "$REPORT_FILE"
echo "Number of CPU cores:" >> "$REPORT_FILE"
nproc >> "$REPORT_FILE"

echo "CPU Frequency:" >> "$REPORT_FILE"
lscpu | grep "CPU MHz" | awk -F: '{print $2 " MHz"}' >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "===== END OF REPORT =====" >> "$REPORT_FILE"

echo "System report generated: $REPORT_FILE"


