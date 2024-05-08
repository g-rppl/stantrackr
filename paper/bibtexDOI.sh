#!/bin/bash
echo >> ./paper/paper.bib
curl -LH "Accept: application/x-bibtex" doi.org/$1 >> ./paper/paper.bib
echo >> ./paper/paper.bib