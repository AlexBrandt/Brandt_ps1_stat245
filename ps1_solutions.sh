#!/usr/bin/env bash

# Alexander Brandt
# SID: 24092167
# ajbrandt@berkeley.edu

############################################################################################################################################
#                                                                                                                                          #
# Question 1a)                                                                                                                             #
#                                                                                                                                          #
############################################################################################################################################

# To begin, use the download handler link provided by UN FAO to procure the relevant .zip file for "apricots"
# which is placed into a defined file, rather than the length output it would default to normally with wget

echo "Downloading data for apricots.  Please wait..."
wget --quiet "http://data.un.org/Handlers/DownloadHandler.ashx?DataFilter=itemCode:526&DataMartId=FAO&Format=csv&c=2,3,4,5,6,7&s=countryName:asc,elementCode:asc,year:desc" -O example_1.zip
echo "Download finished."

# We assume that we have only one file in the .zip archive, but again, for good file naming practices, we store
# the relevant file in a variable called "fn" for file name.

fn=`unzip -Z -1 example_1.zip`

# Confident in our answer, we can now unzip the file

unzip -qq example_1.zip

# Because we will need to sanitize our input a bit, we create a new filename to store our sanitized file, as
# well as count the number of lines in said file.  This will allow us to extract the data minus the header and
# the explanatory information

fns="$fn".sanitized.csv
lc=$(wc -l < $fn)

# Hard coded numbers are hard to avoid here, but we can still store the number of lines needed to clear the 
# in a global variable, then we use sed to extract the data from the header and the explanatory appendix

LINES_TO_STOP=7
sed -n 2,$(($lc - $LINES_TO_STOP))p $fn > $fn.sanitized.csv

# I used the below code to discover what information could be used to parse "regions" from countries, though
# it is not active in the .sh file because it isn't needed.  "Regions" have a + character in their field,
# so now we can use grep to distinguish the two from one another, we remove commas from countries 
# like Iran and finally use to sed replace the " in the file to make it easier to read and manipulate.
#
# cut -d, -f1 $fn.sanitized.csv | sort | uniq 

grep -v + $fns | sed "s/, / - /g" | sed "s/\"//g" > $fn.countries.csv
grep + $fns | sed "s/\"//g" > $fn.regions.csv

# Now we use a counter, starting at 1965, incrementing by 10, and stopping at 2005, to iterate through the years
# of interest.

for i in `seq 1965 10 2005`
do
    echo "The largest apricot producers in $i were..."
    echo ""
    # grep is a poor choice to pull out the years, so we use awk to confirm exact matches in the fourth column
    # and THEN use grep to ensure we are just considering the area that is harvested.  This could be piped into 
    # the below commands, but it seemed unwieldy.  I stored it into a file instead.
    awk -v year="$i" -F , '$4 == year { print }' $fn.countries.csv | grep "Area Harvested" > $fn.countries.$i.csv
    # Now we sort the csv for the selected year on the 6th column, numerically (as opposed to lexigraphically),
    # in reverse order (so the biggest numbers are at the top of the file).  Then "head" selects the five biggest lines.
    # The rankings do indeed vary year to year, with USSR/Russia's fall from #1 between 1985/1995 probably
    # corresponding to the fall of the USSR
    sort --field-separator=',' -r -n -k 6,6 $fn.countries.$i.csv | head -n 5
    echo ""
    echo ""
done

############################################################################################################################################
#                                                                                                                                          #
# Question 1b)                                                                                                                             #
#                                                                                                                                          #
############################################################################################################################################

# Now we repeat with a user defined code.  Much of the code/procedure stays the same.  Now the NUM variable is just
# populated with the user input from "read"

echo "Please enter the agricultural product code of the item you wish to see data for..."
read NUM
echo "Download data for product code $NUM, please wait..."
wget --quiet "http://data.un.org/Handlers/DownloadHandler.ashx?DataFilter=itemCode:"$NUM"&DataMartId=FAO&Format=csv&c=2,3,4,5,6,7&s=countryName:asc,elementCode:asc,year:desc" -O UN_data_$NUM.zip
echo "Download complete."
fn_pc=`unzip -Z -1 UN_data_$NUM.zip`
unzip -qq UN_data_$NUM.zip

# cat is the program that prints out to the screen the information from the preceeding .csv file. But in the
# interest of saving space in the output from my code, I have truncated the file at the first 10 lines. By
# removing the '| head -n 5' one would be able to pipe the full file into any command.
echo "The first five lines of the file just download are..."
cat $fn_pc | head -n 5


############################################################################################################################################
#                                                                                                                                          #
# Question 1c)                                                                                                                             #
#                                                                                                                                          #
############################################################################################################################################

echo "Creating index file, please wait."
wget --quiet http://faostat.fao.org/site/384/default.aspx -O default.aspx

# First, we pull all non-processed crop data by looking for the relevant HTML tag and information.  Then we
# cut out the intervening <td><\td> tags (which make a pretty good delimeter!), and replace them with tabs, 
# given that some of the produce codes have "," in their descriptors and tabs are my next best choice after ,'s.
# However, we only need the 7th and 9th columns of this file (lots of leading whitespace!), so we store these
# in a product lookup table to be used later.

grep \<td\>Crops\<\/td\> default.aspx | sed $'s/\<\/td\>\<td\>/\t/g' | cut -d$'\t' -f 7,9 > product_code_lookup_table.tsv
echo "Index file created."

# We ask the user for their selection, like in 1b)

echo "Please enter the name of an agricultural product which you wish to see data for..."
read productname

# ...and then we search our lookup table (ignoring case).  Note that this method is a little less precise than
# using awk to get the "exact" match.  And using "beans," for example, would actually produce TWO options. This
# is why we use an additional call to "head -n 1".  It isn't ideal, but it's certainly more flexible and less
# tedious than asking the user to put in "Beans, raw."

i=`grep -i $productname product_code_lookup_table.tsv | head -n 1 | cut -f 1`

# If $i is blank (i.e., there was no product that matched the user's query in the lookup table,), we inform the
# user and move on.

if [ -z $i ]; then
    echo "I'm sorry, $productname was not found in the UN FAO database.  Please try again later."
else
    echo "Downloading $productname data..."
    # Otherwise, we download as in previous parts, extract the file, and inform the user of the new filename.
    wget --quiet "http://data.un.org/Handlers/DownloadHandler.ashx?DataFilter=itemCode:$i&DataMartId=FAO&Format=csv&c=2,3,4,5,6,7&s=countryName:asc,elementCode:asc,year:desc" -O UN_data_"$i".zip
    unzip -qq UN_data_"$i".zip
    selection_fn=`unzip -Z -1 UN_data_$i.zip`
    echo "Your $productname data is now ready in file $selection_fn"
fi

############################################################################################################################################
#                                                                                                                                          #
# Question 2)                                                                                                                              #
#                                                                                                                                          #
############################################################################################################################################

# First wget pulls the index.html file from ncdc.noaa.gov.  This will provide very useful as it contains 
# linkes to all of the files, including the .txt files requested by the problem.  Next we use a regular expression
# in grep to build a list of the files (from their linked file names in the href HTML tag) to iterate through
# using a for loop.  We then inform the user, and proceed with the (silent!) download.

# Full disclosure/citation, I needed external help constructing the regular expression, source:
# http://stackoverflow.com/questions/21264626/how-to-strip-out-all-of-the-links-of-an-html-file-in-bash-or-grep-or-batch-and-s
# my expression DOES represent me trying to understand it myself (and doesn't directly draw from code in a
# copy + paste fashion), but I DID want to be transparent about my process/workflow.

wget --quiet http://www1.ncdc.noaa.gov/pub/data/ghcn/daily/
for i in `grep -E -o 'href="([^"#]+.txt)"' index.html | cut -d'"' -f2`
do
    echo "Downloading $i..."
    wget --quiet http://www1.ncdc.noaa.gov/pub/data/ghcn/daily/$i
done
