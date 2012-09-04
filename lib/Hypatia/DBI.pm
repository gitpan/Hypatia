package Hypatia::DBI;
{
  $Hypatia::DBI::VERSION = '0.01.1';
}
use strict;
use warnings;
use Moose;
use DBI;
use namespace::autoclean;



has 'dsn'=>(isa=>'Str',is=>'ro',required=>1);

has [qw(username password)]=>(isa=>'Str',is=>'ro',default=>"");

has 'attributes'=>(isa=>'HashRef',is=>'ro',default=>sub{return {}});


has 'table'=>(isa=>'Str',is=>'ro',predicate=>'has_table');
has 'query'=>(isa=>'Str',is=>'ro',predicate=>'has_query');


has 'dbh'=>(isa=>'Maybe[DBI::db]',is=>'ro',init_arg=>undef,lazy=>1,builder=>'_connect_db');

#Disabling this flag will skip the database connection.  This is for testing only.

has 'connect'=>(isa=>'Bool',is=>'ro',default=>1);


sub data
{
	my $self=shift;
	
	my @raw_columns=grep{ref $_ eq ref "" or ref $_ eq ref []}@_;
	
	my $query;
	
	foreach(@_)
	{
		if(ref $_ eq ref {})
		{
			if(defined $_->{query})
			{
				$query=$_->{query};
				last;
			}
		}
	}
	
	my @columns=();
	foreach(@raw_columns)
	{
		if(ref $_ eq ref [])
		{
			foreach my $col(@{$_})
			{
				push @columns, $col;
			}
		}
		else
		{
			push @columns,$_;
		}
	}
	

	my $dbh=$self->dbh;
	
	unless(@columns)
	{
		warn "WARNING: no arguments passed to the data method";
		return undef;
	}
	
	confess "No active database connection" unless $dbh->{Active};
	
	unless($query)
	{
		$query=$self->_build_query(@columns);
	}
	
	confess "Unable to build query via the _build_query method" unless defined $query;
	
	
	my $data={};
	
	$data->{$_}=[] foreach(@columns);
	
	my $sth=$dbh->prepare($query) or confess $dbh->errstr;
	$sth->execute or confess $dbh->errstr;
	
	my $num_rows=0;
	
	while(my @row=$sth->fetchrow_array)
	{
		foreach(0..$#columns)
		{
			push @{$data->{$columns[$_]}},$row[$_];
		}
		$num_rows++;
	}
	
	$sth->finish;
	
	if($num_rows==0)
	{
		warn "WARNING: Zero rows of data returned by the following query:\n$query\n";
		return undef;
	}
	elsif($num_rows==1)
	{
		warn "WARNING: Only one row of data returned by the following query:\n$query\n";
	}
	
	return $data;
}



sub _connect_db
{
	my $self=shift;
	
	if($self->connect)
	{
	    my $dbh=DBI->connect($self->dsn,$self->username,$self->password,$self->attributes) or confess DBI->errstr;
	
	    return $dbh;
	}
	else
	{
	    return undef;
	}
}


sub _build_query
{
	my $self=shift;
	my @columns=@_;
	
	unless(@columns)
	{
		warn "WARNING: no arguments passed to the _build_query method";
		return undef;
	}
	
	my @dereferenced_columns=();
	foreach(@columns)
	{
		if(ref $_ eq ref "")
		{
			push @dereferenced_columns,$_;
		}
		else
		{
			push @dereferenced_columns,@{$_};
		}
	}
	my $column_list=join(",",@dereferenced_columns);
	my $is_not_null=join(" is not null and ",@dereferenced_columns) . " is not null ";
	
	
	if($self->has_table)
	{
		return "select $column_list from " . $self->table . " where $is_not_null group by $column_list order by $column_list";
	}
	elsif($self->has_query)
	{
		return "select $column_list from(" . $self->query . ")query where $is_not_null group by $column_list order by $column_list";
	}
	
	#There should be no reason why we wouldn't return by this point...
	#But just in case....
	return undef;
}



sub BUILD
{
	my $self=shift;
	
	if(($self->has_query and $self->has_table) or (not $self->has_query and not $self->has_table))
	{
		confess "Exactly one of the 'table' or 'query' attributes must be set";
	}
}



__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

Hypatia::DBI

=head1 VERSION

version 0.01.1

=head1 ATTRIBUTES

=head2 dsn,username,password,attributes

These are strings that are fed directly into the C<connect> method of L<DBI>.  The C<dsn> attribute is required and both C<username> and C<password> default to C<""> (which is useful if, for example, you're using a SQLite database).  The hash reference C<attributes> contains any optional key-value pairs to be passed to L<DBI>'s C<connect> method.  See the L<DBI> documentation for more details.

=head2 query,table

These strings represent the source of the data within the database represented by C<dsn>.  In other words, if your data source is from DBI, then you can pull data via a table name (C<table>) or via a query (C<query>).  Don't set both of these, as this will cause your script to die.

=head2 dbh

This is the database handle returned from the C<connect> method of L<DBI>.  This attribute is automatically set at the time of object creation.  Don't tinker with it (just use it).

=head1 METHODS

=head2 C<data(@columns,{query=>$query}])>

This method grabs the resulting data from the query returned by the C<build_query> method.  The returned data structure is a hash reference of array references where the keys correspond to column names (ie the elements of the C<@columns> array) and the values of the hash reference are the values of the given column returned by the query from the C<_build_query> method.

The optional hash reference argument allows for the overriding of the query generated by the C<_build_query> method.

=head1 AUTHOR

Jack Maney <jack@jackmaney.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Jack Maney.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
