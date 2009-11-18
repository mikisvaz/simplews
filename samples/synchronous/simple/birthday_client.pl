use SOAP::Lite service => "file:BirthdayWS.wsdl";

print greet 'Mike', 32;
print "\n";

foreach ('Mike', 'Lisa'){
    my $name = $_;
    if (greeted $name){
        print "I greated $name\n";
    }else{
        print "I did not greet $name\n";
    }
}
