#!/bin/bash
# Convert a .md file to a html file.

meta_files=../*/*.meta
header_file="header-home.html"
footer_file="footer-home.html"
cat $header_file > ../index.html
for meta in $meta_files; do
    # Process meta into html and put it in index.html
    title="`cat $meta | grep 'title=' | cut -d '=' -f 2`"
    summary="`cat $meta | grep 'summary=' | cut -d '=' -f 2`"
    date="`cat $meta | grep 'date=' | cut -d '=' -f 2`"
    # Make relative to ../ and get index.html
    html_file=`dirname $meta | cut -c 4-`/index.html
    cat >> ../index.html <<EOF
    <section class="intro">
        <h2><a href="$html_file">$title</a></h2>
        <p class="summary">$summary</p>
        <span class="date">$date</span>
    </section>
EOF
done
cat $footer_file >> ../index.html
