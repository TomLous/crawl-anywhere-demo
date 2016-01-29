import sys
import urllib2
import re

def main():
	url = "http://apache.proserve.nl/zookeeper/"

	usock = urllib2.urlopen(url)
	content = usock.read()
	usock.close()


	versions = re.findall('(\d+\.\d+\.\d+)\/', content)

	versions.sort(key=lambda s: map(int, s.split('.')))

	
	print versions[-1]
	

main()