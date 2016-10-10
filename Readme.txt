Goal

Instructions on how to run an attached PowerShell script which will generate a server utilization report from the past day's usage.

The report will contain resource and utilization data for each server in the account, including sub accounts, as well as reports identifying servers with average CPU, RAM or Storage utilization over 70% and under 25% for the time period.

 

Audience

Any CenturyLink Cloud employee

CenturyLink Cloud customers

 

Prerequisites

Access to the Control Portal with at least account viewer or billing manager privileges

CenturyLink Cloud API v1 Key and Password, associated with your Control Portal account

PowerShell

Running either locally on a Windows laptop or remotely in a Windows Server Virtual Machine

It is recommended that you run this script from the ISE with administrator privileges

An application that can open .csv files

 

Steps

In order to enable scripts on your machine, first run the following command in PowerShell:
Set-ExecutionPolicy RemoteSigned
Note: You may need to launch PowerShell with elevated privileges
Download the PowerShell script "CLCAPIPullServerMetricsV2 - Public.ps1" that is attached to this article
Run the script you just downloaded
Enter the alias of the account you will be creating the report for
Enter your API v1 key
Enter your API v1 Password
Enter your control portal username
Enter your control portal password
The output will be displayed in a .csv file. The file will be stored locally at C:\Users\Public\CLC\
 

Version History

10/10/2016 - Script updated to reflect updates to the CLC API

4/6/2016 - Version 3 uploaded - Matt Schwabenbauer

4/1/2016 - Version 2 uploaded - Matt Schwabenbauer