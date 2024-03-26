IO-Reverse
==========

## PURPOSE

The IO::Reverse module has one purpose: to read a file from the end to the beginning, presenting lines in reverse order.

Example:

create a test file

```text
$  cat <<-EOF > reverse-test.txt
> this is line 1
> this is line 2
> this is line 3
> this is line 4
> this is line 5
> EOF
```

read from EOF to BOF

```text
$  ./reverse.pl --file reverse-test.txt
this is line 5
this is line 4
this is lint 3
this is line 2
this is line 1
```

There are other modules that may do this.

There is also `tac` on Linux, which will also read a file backwards, line by line.

While `tac` is about 4x faster than IO::Reverse, IO::Reverse is pure Perl that I can easily use where needed.

The `tac` program when available,  may even be incorporated in a later version of IO::Reverse because it is fast.


## INSTALLATION

To install this module, run the following commands:

```text
	perl Makefile.PL
	make
	make test
	make install
```

## SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the perldoc command.

```text
    perldoc IO::Reverse
```

You can also look for information at:

[RT, CPAN's request tracker (report bugs here)](https://rt.cpan.org/NoAuth/Bugs.html?Dist=IO-Reverse)

[CPAN Ratings](https://cpanratings.perl.org/d/IO-Reverse)

[Search CPAN](https://metacpan.org/release/IO-Reverse)


## LICENSE AND COPYRIGHT

This software is Copyright (c) 2023 by Jared Still.

This is free software, licensed under:

  The MIT License

