#!/usr/bin/env perl

use strict;
use warnings;
use List::Util qw<any>;
use DBI;

exit unless exists $ENV{'TGUTILS_TYPE'};
exit unless $ENV{'TGUTILS_TYPE'} eq 'TEXT';

$/ = undef;
my $text = <>;

# Indicios de que alguien ha cagado
my @DUMP_TRIGGERS = (
    "caga", "cagu", "jiñ", "vientr", "plant", "deposit", "bomb", "defec",
    "apunt", # Verbos
    "tremend[ao]", "salvaj", # Adjetivos
    "pino", "pinaco", "ñordo", "truñ", "chusc", "caca", "caco", "caqu", "baño",
    "mierda", "topo", "mojón", "zurull", "wc", "roca", "retrete", "shit", # Sustantivos
    "a gust", "otr[ao]", "💩" # Otros
    );
my @PHRASES = (
    "Estoy orgulloso de ti, %s.",
    "¡Así se hace %s! 👏👏",
    "¿Otra vez, %s? Tu salud intestinal es admirable, felicidades.",
    "Te habrás quedado a gusto.",
    "Sigue así %s, mostro, titán, coloso, crack, máquina, mastodonte, huracán.",
    "%s Oh capitán, mi capitán.",
    );
my $dbh;

init_schema() unless -f 'escato.db';
my ($tg_chat_id, $tg_id, $tg_username) =
    @ENV{'TGUTILS_CHAT_ID', 'TGUTILS_FROM_ID', 'TGUTILS_FROM_USERNAME'};
if ($tg_chat_id eq $tg_id || lc($text) =~ /^\@escatobot/) {
    if (any { lc($text) =~ $_ } @DUMP_TRIGGERS) {
        save_dump();
    } else {
        show_dumps();
    }
}

sub show_dumps {
    $dbh ||= DBI->connect("DBI:SQLite:dbname=escato.db", { AutoCommit => 0, RaiseError => 1 });

    my ($sec, $min, $hour) = localtime();
    print
        $hour < 4 || $hour > 20 ? "Hola, buenas noches. " :
        $hour > 13 ? "Hola, buenas tardes. " :
        "Hola, buenos días. ";

    if ($tg_chat_id eq $tg_id) {
        my ($month, $year) =
            @{tg_id_dumps($tg_id)}{'month', 'year'};

        print "Te cuento, $tg_username. Este mes has cagado $month veces. En total llevas $year truños en lo que vamos de año.\n";
    } else {
        print "Os cuento, shures:\n";
        my $position = 1;
        my @shures;
        foreach my $shur (values %{chat_members($tg_chat_id)}) {
            push @shures, {username => $shur->{'username'},
                           data => tg_id_dumps($shur->{'id'})};
        }
        my $graph = gen_graph(map { $_->{points} } @shures);
        foreach my $shur (sort { $b->{data}{month} <=> $a->{data}{month} } @shures) {
            printf "%d - @%s ha cagado %d veces este mes, y %d al año.\n",
                $position++, $shur->{username}, $shur->{data}{month}, $shur->{data}{year};
        }
    }
}

sub gen_graph {
    my $points = shift;
}

sub chat_members {
    my $tg_chat_id = shift;
    $dbh ||= DBI->connect("DBI:SQLite:dbname=escato.db", { AutoCommit => 0, RaiseError => 1 });
    my $sth = $dbh->prepare('SELECT U.id, U.username FROM tg_chat_users CU JOIN tg_users U ON U.id = CU.tg_id WHERE CU.tg_chat_id = ?');
    $sth->execute($tg_chat_id);

    return $sth->fetchall_hashref('id');
}

sub tg_id_dumps {
    my $tg_id = shift;

    $dbh ||= DBI->connect("DBI:SQLite:dbname=escato.db", { AutoCommit => 0, RaiseError => 1 });

    my $sth = $dbh->prepare('SELECT date FROM monthly_dumps WHERE tg_id = ?');
    $sth->execute($tg_id);
    my @points;
    my %stats = (points => \@points, total => 0, year => 0, month => 0, day => 0);
    my (undef, undef, undef, $day, $month, $year) = localtime();
    $month++;
    $year += 1900;
    while (my $row = $sth->fetch()) {
        push @points, $row;
        my ($date) = @$row;
        my ($y, $m, $d) = $date =~ /(\d+)-(\d+)-(\d+)/;
        $stats{total} += 1;
        $stats{year} += 1 if $y == $year;
        $stats{month} += 1 if $m == $month;
        $stats{day} += 1 if $d == $day;
    }
    \%stats;
}

sub init_schema {
    $dbh ||= DBI->connect("DBI:SQLite:dbname=escato.db", { AutoCommit => 0, RaiseError => 1 });
    $dbh->prepare('CREATE TABLE tg_users (
                 id INTEGER PRIMARY KEY,
                 username TEXT NOT NULL UNIQUE
                 )')->execute();
    $dbh->prepare('CREATE TABLE tg_chats (
                 id INTEGER PRIMARY KEY
                 )')->execute();
    $dbh->prepare('CREATE TABLE tg_chat_users (
                 tg_chat_id INTEGER NOT NULL,
                 tg_id INTEGER NOT NULL,
                 PRIMARY KEY (tg_chat_id, tg_id),
                 FOREIGN KEY (tg_id) REFERENCES tg_users(id),
                 FOREIGN KEY (tg_chat_id) REFERENCES tg_chats(id)
                 )')->execute();
    $dbh->prepare('CREATE TABLE monthly_dumps (
                 id INTEGER PRIMARY KEY,
                 tg_id INTEGER NOT NULL,
                 date DATE NOT NULL,
                 FOREIGN KEY (tg_id) REFERENCES tg_users(id)
                 )')->execute();
}

sub save_dump {
    $dbh ||= DBI->connect("DBI:SQLite:dbname=escato.db", { AutoCommit => 0, RaiseError => 1 });
    $dbh->prepare('INSERT OR REPLACE INTO tg_users VALUES (?, ?)')
        ->execute($tg_id, $tg_username);
    $dbh->prepare('INSERT OR IGNORE INTO tg_chats VALUES (?)')
        ->execute($tg_chat_id);
    $dbh->prepare('INSERT OR IGNORE INTO tg_chat_users VALUES (?, ?)')
        ->execute($tg_chat_id, $tg_id);

    $dbh->prepare('INSERT INTO monthly_dumps
                 (tg_id, date)
                 VALUES
                 (?, DATETIME("now"))')->execute($tg_id);
    my (undef, undef, undef, $mday, $mon) = localtime();
    my $phrase = sprintf $PHRASES[rand @PHRASES], "@" . $tg_username;
    if ($mday == 8 && $mon == 2) {
        $phrase =~ s/o([a-z]?([^a-z]|$))/e$1/g;
    }
    print $phrase;
}

