import sys
import urllib2
import re

def main():
	url = "http://dev.mysql.com/downloads/connector/j/"

	usock = urllib2.urlopen(url)
	content = usock.read()
	usock.close()


	versions = re.findall('Connector/J (\d+\.\d+\.\d+)', content)

	versions.sort(key=lambda s: map(int, s.split('.')))

	#print content
	print versions[0]
	

main()