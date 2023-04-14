# Intro

DEMOCRAT is a consensus machine translation (MT) system.  This means
that it takes the output of one or more "regular" MT systems and
combines the output of these into one.  The underlying idea is that by
combining the output of several MT systems, errors can be averaged
out.

The workings of the algorithm can be found in the MT Summit paper:
Menno van Zaanen & Harold Somers (2005)
DEMOCRAT: Deciding between Multiple Outputs Created by Automatic Translation.
MT Summit X: The Tenth Machine Translation Summit (Phuket, Thailand).
pp. 173-180.


# Program

The interface of the DEMOCRAT program is very simple.


Usage: ./democrat.pl [OPTION]...

This program reads in a file with translations (separated by a * on a
line) and finds the best combinations of words from these sentences.

  -i FILE   Name of input file (default: -)
  -o FILE   Name of output file (default: -)
  -h        Show this help and exit


The input file should look like this:
translation1 of input sentence1
translation2 of input sentence1
translation3 of input sentence1
*
translation1 of input sentence2
translation2 of input sentence2
translation3 of input sentence2
*
etc.

The number of translations may be different for each input sentence,
but typically it will have the same number per sentence (namely the
number of MT systems being used).

DEMOCRAT outputs the combined translations of the input sentences,
again separated by a * in the output file (the -o option).

Finally, it gives a summary on standard output.


Summary
======================================================
filename:                       <filename>
# of sentences:                 <num>
# of random choices:            <num>
total # of choices:             <num>
======================================================


<filename> is the name of the input file.  Then the number of
sentences is given (each sentence may have several translations).
Then information about choices in finding the best translations is
given.  The number of random choices indicates how many times a choice
had to made at random (i.e. several choices were available).  The
total number of choices indicates how many choices were made in total.
