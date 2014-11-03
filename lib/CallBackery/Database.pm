package CallBackery::Database;

# $Id: Database.pm 542 2013-12-12 16:36:34Z oetiker $

use Mojo::Base -base;

use DBI;
use Data::Dumper;
use Carp qw(croak);
use CallBackery::Exception qw(mkerror);
use Scalar::Util qw(weaken);

=head1 NAME

CallBackery::Database - database access helpers

=head1 SYNOPSIS

 use CallBackery::Database;
 my $db = CallBackery::Database->new(app=>$self->config);
 my ($fields,$values) = $self->map2sql(table,data);
 my $selWhere = $self->map2where(table,data);
 my $rowHash = $self->fetchRow(table,{field=>val,field=>val},selExpression?);
 my $value = $self->fetchValue(table,{field=>val,field=>val},column);
 my $id = $self->matchData(table,{field=>val,field=>val});
 my $id = $self->lookUp(table,field,value);
 my $id = $self->updateOrInsertData(table,{dataField=>val,...},{matchField=>val,...}?);
 my $id = $self->insertIfNew(table,{field=>val,field=>val});

=head1 DESCRIPTION

Database access helpers.

=head2 config

object needs access to the system config to get access to the database

=cut

has app => sub {
    croak "app property is required";
};

has config => sub {
    shift->app->config;
};


=head2 dhb

a dbi database handle

=cut

my $lastFlush = time;


sub dbh {
    my $self = shift;
    my $db = $self->config->cfgHash->{BACKEND}{cfg_db};
    my $dbExists = -s $db;
    my $dbh = DBI->connect_cached('dbi:SQLite:dbname='.$db,'','',{
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
        ShowErrorStatement => 1,
        sqlite_unicode => 1, # yes we are commited to utf8!
        FetchHashKeyName=>'NAME_lc',
        afb_db_generation => ( (stat $db.'.flush')[9] || 'none' ), # do NOT cache if we flushed
    }) or die mkerror(2,DBI->errstr());
    $dbh->do('PRAGMA foreign_keys = ON');
    if (not $dbExists){
        $self->makeTables($dbh);
    }
    return $dbh;
}

sub makeTables {
    my $self = shift;
    my $dbh = shift;
    $dbh->do(<<'SQL');
CREATE TABLE user (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_login TEXT UNIQUE,
    user_family TEXT,
    user_given TEXT,
    user_password TEXT,
    user_note TEXT
)
SQL
    $dbh->do(<<'SQL');
CREATE TABLE right (
    right_id INTEGER PRIMARY KEY AUTOINCREMENT,
    right_key TEXT UNIQUE
)
SQL
    $dbh->do(<<'SQL');
CREATE TABLE userright (
    userright_id INTEGER PRIMARY KEY AUTOINCREMENT,
    userright_user INTEGER REFERENCES user(user_id),
    userright_right INTEGER REFERENCES right(right_id)
)
SQL
    $dbh->do(<<'SQL');
CREATE UNIQUE INDEX userright_idx 
    ON userright(userright_user,userright_right)
SQL

    $dbh->do(<<'SQL');
CREATE TABLE config (
    config_id TEXT PRIMARY KEY,
    config_value TEXT
)
SQL
    $dbh->do(<<'SQL');
CREATE TABLE history (
    history_id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    history_user TEXT,
    history_module TEXT,
    history_action TEXT
)
SQL
}

=item my($fields,$values) = $self->C<map2sql(table,data)>;

Provide two hash pointers and quote the field names for inclusion into an
SQL expression. Build field names according to the table_field rule.

=cut

sub map2sql {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my @values;
    my @fields;
    my $dbh = $self->dbh;
    while (my($field, $value) = each %$data) {
        push @fields,$dbh->quote_identifier($table."_".$field);
        push @values,$value;
    }
    return (\@fields,\@values);
}

=item my $sqlWhere = $self->C<map2where(table,data)>;

build a where statement Find a record matching the given data in a table the
data is a map. Quote field names and values.  Build field names according to
the table_field rule.

=cut

sub map2where {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my $dbh = $self->dbh;
    my @expression;
    while (my($field, $value) = each %$data) {
        my $field = $dbh->quote_identifier($table."_".$field);
        my $expr;
        if (defined $value){
            $expr = $field.' = '.$dbh->quote($value);
        }
        else {
            $expr = $field.' is null';
        }            
        push @expression, $expr;
    }
    return (join ' AND ',@expression);
}

=item $hashRef = $self->C<getMap(table,column)>;

Get an array of hashes with id and label tags:

 [{id: x, label: y},{id ...},...]

=cut

sub getMap {
    my $self = shift;
    my $table = shift;
    my $column = shift;
    my $dbh = $self->dbh;
    my $sqlId = $dbh->quote_identifier($table."_id");
    my $sqlColumn = $dbh->quote_identifier($table."_".$column);
    my $sqlTable = $dbh->quote_identifier($table);
    my $SQL = <<"SQL";
        SELECT $sqlId as model, $sqlColumn as label
          FROM $sqlTable
          ORDER by $sqlColumn
SQL
    return $dbh->selectall_arrayref($SQL,{Slice=>{}});
}

=item $hashRef = $self->C<getRowHash(table,{key=>value,....},$selectExpr?)>;

Get a hash with record index as key. Optionally with a list of columns to return.

 {
   2 => { a=>x, b=>y },
   3 => { a=>k, b=>r }
 }

=cut

sub getRowHash {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my $selectCols = shift // '*';
    my $dbh = $self->dbh;
    my $sqlTable = $dbh->quote_identifier($table);
    my $sqlWhere = $self->map2where($table,$data);
    my $SQL = <<"SQL";
        SELECT $selectCols 
          FROM $sqlTable
         WHERE $sqlWhere
SQL
    return $dbh->selectall_hashref($SQL,$table."_id",{Slice=>{}});
}


=item $id = $self->C<fetchRow(table,{key=>value,key=>value},$selectExp ?)>;

Find a record matching the given data in a table and return a hash of the matching record.

=cut

sub fetchRow {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my $selectCols = shift // '*';
    my $dbh = $self->dbh;
    my $sqlWhere = $self->map2where($table,$data);
    my $sqlTable = $dbh->quote_identifier($table);
    my $SQL = <<"SQL";
        SELECT $selectCols
          FROM $sqlTable
         WHERE $sqlWhere
SQL
    return $dbh->selectrow_hashref($SQL);
}

=item $id = $self->C<fetchValue(table,{key=>value,key=>value},column)>;

Find a record matching the given data in a table and returns the value in column.

=cut

sub fetchValue {
    my $self = shift;
    my $table = shift;
    my $where = shift;
    my $column = shift;
    my $dbh = $self->dbh;
    my $row = $self->fetchRow($table,$where,$dbh->quote_identifier($table.'_'.$column));
    if ($row){
        return $row->{$table.'_'.$column};
    }
    else {
        return undef;
    }
}


=item $id = $self->C<matchData(table,data)>;

Find a record matching the given data in a table
the data is a map.

=cut

sub matchData {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my $found = $self->fetchValue($table,$data,"id");
    return $found;
        
}

=item $id = $self->C<lookUp(table,column,value)>

Lookup the value in table in table_column and return table_id.
Throw an exception if this fails. Use matchData if you are just looking.

=cut

sub lookUp {
    my $self = shift;
    my $table = shift;
    my $column = shift;
    my $value = shift;
    my $id = $self->matchData($table,{$column => $value})
        or die mkerror(1349,"Lookup for $column = $value in $table faild"); 
    return $id;
}

=item $id = $self->C<updateOrInsertData(table,data,match?)>

Insert the given data into the table. If a match map is given, try an update first
with the given match only insert when update has 0 hits.

=cut

sub updateOrInsertData {
    my $self = shift;
    my $table = shift;
    my $data = shift;
    my $match = shift;
    my $dbh = $self->dbh;
    my ($colNames,$colValues) = $self->map2sql($table,$data);
    my $sqlTable = $dbh->quote_identifier($table);
    my $sqlIdCol = $dbh->quote_identifier($table."_id"); 
    my $sqlColumns = join ', ', @$colNames;
    my $sqlSet = join ', ', map { "$_ = ?" } @$colNames;
    my $sqlData = join ', ', map { '?' } @$colValues;
    if ($match){ # try update first if we have an id
        my $matchWhere = $self->map2where($table,$match);
        my $SQL = <<"SQL";
        UPDATE $sqlTable SET $sqlSet
        WHERE $matchWhere
SQL
        my $count =  $dbh->do($SQL,{},@$colValues);
        if ($count > 0){
            return ( $data->{id} // $match->{id} );
        }
    }
    my $SQL = <<"SQL";
        INSERT INTO $sqlTable ( $sqlColumns )
        VALUES ( $sqlData )
SQL
    $dbh->do($SQL,{},@$colValues);

    # non serial primary key, id defined by user
    if (exists $data->{'id'}){
        return $data->{'id'};
    }
    # serial primary key
    else{ 
        return $dbh->last_insert_id(undef,undef,$table,$table."_id");    
    }
}

=item $id = $self->C<insertIfNew(table,data)>

Lookup the given data. If it is new, insert a record. Returns the matching Id.

=cut

sub insertIfNew {
    my $self = shift; 
    my $table = shift;
    my $data = shift;
    return ( $self->matchData($table,$data)
           // $self->updateOrInsertData($table,$data));
}

=item $id = $self->C<deleteData(table,id)>

Delete data from table. Given the record id.
Returns true if the record was deleted.

=cut

sub deleteData {
    my $self = shift; 
    my $table = shift;
    my $id = shift;
    return $self->deleteDataWhere($table,{id=>$id});
}

=item $id = $self->C<deleteDataWhere(table,{key=>val,key=>val})>

Delete data from table. Given the column title and the matching value.
Returns true if the record was deleted.

=cut

sub deleteDataWhere {
    my $self = shift; 
    my $table = shift;
    my $match = shift;
    my $val = shift;
    my $dbh = $self->dbh;
    my $sqlTable = $dbh->quote_identifier($table);
    my $matchWhere = $self->map2where($table,$match);
    my $SQL = 'DELETE FROM '.$sqlTable.' WHERE '.$matchWhere;
#    say $SQL;
    return $dbh->do($SQL);
}

1;
__END__

=back

=head1 COPYRIGHT

Copyright (c) 2013 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobi Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2010-06-12 to 1.0 initial
 2013-11-19 to 1.1 converted to mojo

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
