#!/bin/bash
# Convert a .md file to a html file.

md_filepath=$1
md_path=`dirname "$md_filepath"`/
md_filename=`basename "$md_filepath" .md`
meta_filepath=""
html_filepath=$md_filename.html
header_filepath=$md_path"header.html"
footer_filepath=$md_path"footer.html"
if [ ! -z "$2" ]; then
  if [ ! -z "$3" ]; then
    html_filepath=$2
    meta_filepath=$3
  elif [ ${2: -4} == "meta" ]; then
    meta_filepath=$2
  else
    html_filepath=$2
  fi
fi

if [ ! -f $header_filepath ]; then
    header_filepath="header.html"
fi
if [ ! -f $footer_filepath ]; then
    footer_filepath="footer.html"
fi

cat $header_filepath > $html_filepath
./Markdown.pl $md_filepath >> $html_filepath
cat $footer_filepath >> $html_filepath

if [ ! -z "$meta_filepath" ]; then
  while read line; do
    id="`echo $line | cut -d '=' -f 1`"
    value="`echo $line | cut -d '=' -f 2`"
    # Replace $id with value
    sed -i '' -E 's|\$'"$id"'|'"$value"'|g' $html_filepath
  done < $meta_filepath
fi

