#!/usr/bin/perl -w
use strict;
use warnings;

#tanxy
#
# rwb.pl (Red, White, and Blue)
#
#
# Example code for EECS 339, Northwestern University
#
#
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any. 
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not> 
#
# 4. The script then generates relevant html based on act, run, and other 
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;



#
# You need to override these for access to your database
#
my $dbuser="xto633";
my $dbpasswd="z7uugm7XQ";
my $encrypt="xiaoyang";
#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";

#Then another cookie to get the location of the voter from javascript
my $Location ="Location";
my $locationcookie = cookie($Location);
#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


if (defined(param("act"))) { 
  $action=param("act");
  if (defined(param("run"))) { 
    $run = param("run") == 1;
  } else {
    $run = 0;
  }
} else {
  $action="base";
  $run = 1;
}

my $dstr;

if (defined(param("debug"))) { 
  # parameter has priority over cookie
  if (param("debug") == 0) { 
    $debug = 0;
  } else {
    $debug = 1;
  }
} else {
  if (defined($inputdebugcookiecontent)) { 
    $debug = $inputdebugcookiecontent;
  } else {
    # debug default from script
  }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anonanon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
	my $encrypt_password;
    ($user,$password) = (param('user'),param('password'));
	if ($user eq "root")
    {
    	$encrypt_password = $password;
    }
    else
    {
    	$encrypt_password = crypt($encrypt, $password);
    }
    if (ValidUser($user,$encrypt_password)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain=1;
      $action="login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon","anonanon");
  }
} 


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie=1;
  $action = "base";
  $user = "anon";
  $password = "anonanon";
  $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie=cookie(-name=>$cookiename,
		    -value=>$outputcookiecontent,
		    -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) { 
  my $cookie=cookie(-name=>$debugcookiename,
		    -value=>$outputdebugcookiecontent);
  push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Red, White, and Blue</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
#print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"rwb.css\";\n</style>\n";
  

print "<center>" if !$debug;


#
#
# The remainder here is essentially a giant switch statement based
# on $action. 
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login") { 
  if ($logincomplain) { 
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !$run) { 
    print start_form(-name=>'Login'),
      h2('Login to Red, White, and Blue'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'run',default=>['1']),
		submit,
		  end_form;
  }
}



#
# BASE
#
# The base action presents the overall page to the browser
#
#
#
if ($action eq "base") { 
  #
  # Google maps API, needed to draw the map
  #
  print "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js\" type=\"text/javascript\"></script>";
  print "<script src=\"http://maps.google.com/maps/api/js?sensor=false\" type=\"text/javascript\"></script>";
  
  #
  # The Javascript portion of our app
  #
  print "<script type=\"text/javascript\" src=\"rwb.js\"> </script>";
  



  #
  #
  # And something to color (Red, White, or Blue)
  #
  print "<div id=\"color\" style=\"width:100\%; height:10\%\"></div>";

  #
  #
  # And a map which will be populated later
  #
  print "<div id=\"map\" style=\"width:100\%; height:80\%\"></div>";
 

#############apearance of the information option

	my @cycle_rows;
	eval { @cycle_rows = ExecSQL($dbuser, $dbpasswd, "select distinct cycle from cs339.committee_master");};
 
	print "<form>
	<input type=\"checkbox\" id = \"committee\" >COMMITTEE<br>
	<input type=\"checkbox\" id = \"candidate\" >CANDIDATE<br>
	<input type=\"checkbox\" id = \"individual\" >INDIVIDUAL<br>";


######### if the user has opinion permission show the opinion table
if (UserCan($user,"query-opinion-data")){
	print "<input type=\"checkbox\" id = \"opinion\" >OPINION<br>";
}
##############################
	print "<select multiple=\"multiple\" size = \"1\" id =\"cycles\" >";
	foreach(@cycle_rows)
	{
		print "<option id = @{$_}  value = @{$_} class = 'cycle_year'>@{$_}</option>";
	}
	print "</select>";

	print "<button type = \"button\" id = \"apply\" onclick = \"ViewShift()\">apply</button>";
	print "</form>";


##########################summaries
	print "
<table border=\"1\" style=\"width:500px\">
  <tr>
		<th>Statistics</th>
    <th>Dem Money</th>
    <th>Rep Money</th>
	<th>Dem Count</th>
    <th>Rep Count</th>
  </tr>
  <tr id = \"comm\">
		<th>Committees</th>
    <th id = \"dem_comm_money\">Null</th>
    <th id = \"rep_comm_money\">Null</th>
<th id = \"dem_comm_count\">Null</th>
    <th id = \"rep_comm_count\">Null</th>
  </tr>
  <tr id = \"indv\">
		<th >Individuals</th>
    <th id = \"dem_indv_money\">Null</th>
    <th id = \"rep_indv_money\">Null</th>
<th id = \"dem_indv_count\">Null</th>
    <th id = \"rep_indv_count\">Null</th>
  </tr>
</table>";



#########################@print the opinions

if (UserCan($user,"query-opinion-data")){
print "
<table border=\"1\" style=\"width:500px\">
  <tr>
		<th>standard deviation</th>
    <th>average</th>
    <th>Dem Opinions</th>
	<th>Rep Opinions</th>
  </tr>
  <tr id = \"opn\" >
	<th id = \"std\">Null</th>
    <th id = \"avg\">Null</th>
    <th id = \"dem_o\">Null</th>
	<th id = \"rep_o\">Null</th>
  </tr>
  
</table>";}


  
  #
  # And a div to populate with info about nearby stuff
  #
  #
  if ($debug) {
    # visible if we are debugging
    print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
  } else {
    # invisible otherwise
    print "<div id=\"data\" style=\"display: none;\"></div>";
  }
	

# height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";
  

  #
  # User mods
  #
  #
  if ($user eq "anon") {
    print "<p>You are anonymous, but you can also <a href=\"rwb.pl?act=login\">login</a></p>";
  } else {
    print "<p>You are logged in as $user and can do the following:</p>";
    if (UserCan($user,"give-opinion-data")) {
      print "<p><a href=\"rwb.pl?act=give-opinion-data\">Give Opinion Of Current Location</a></p>";
    }
    if (UserCan($user,"give-cs-ind-data")) {
      print "<p><a href=\"rwb.pl?act=give-cs-ind-data\">Geolocate Individual Contributors</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"invite-users")) {
      print "<p><a href=\"rwb.pl?act=invite-user\">Invite User</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"add-users")) { 
      print "<p><a href=\"rwb.pl?act=add-user\">Add User</a></p>";
    } 
    if (UserCan($user,"manage-users")) { 
      print "<p><a href=\"rwb.pl?act=delete-user\">Delete User</a></p>";
      print "<p><a href=\"rwb.pl?act=add-perm-user\">Add User Permission</a></p>";
      print "<p><a href=\"rwb.pl?act=revoke-perm-user\">Revoke User Permission</a></p>";
    }
    print "<p><a href=\"rwb.pl?act=logout&run=1\">Logout</a></p>";
  }

}

#
#
# NEAR
#
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
  my $latne = param("latne");
  my $longne = param("longne");
  my $latsw = param("latsw");
  my $longsw = param("longsw");
  my $whatparam = param("what");
  my $format = param("format");
  my $cycle = param("cycle");
  my %what;
  
  $format = "table" if !defined($format);
  $cycle = "1112" if !defined($cycle);

	my @cyclelist = split(/\s*,\s*/,$cycle);
  my @sqlized = map {"\'" . "$_" . "\'"} @cyclelist;
  my $sqlized_list = join(', ', @sqlized);
  $sqlized_list = $cycle;


  if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
	      candidates => 1,
	      individuals =>1,
	      opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
	       

  if ($what{committees}) { 
    my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby committees</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{candidates}) {
    my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby candidates</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{individuals}) {
    my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby individuals</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{opinions}) {
    my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby opinions</h2>$str";
      } else {
	print $str;
      }
    }
  }
}

#invite-user

if ($action eq "invite-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"invite-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to invite users.');
  } 
  else {
    if (!$run) { 
      my @permission;
      @permission=GetUserPerm($user);
      print start_form(-name=>'InviteUser'),
	h2('Invite User'),
          "Email : ", textfield(-name=>'email'),
		p,
        h2('Select permissions of the invitee:'),
          checkbox_group(-name=>'permit',-values=>\@permission,),
                p,
	    hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['invite-user']),
		  submit,
		    end_form,
		      hr;
    } else {
      
      my $email=param('email');
      my @inpermission=param('permit');
      my $error=0;
      $error=UserInvite($email,@inpermission);
      if ($error) { 
	print "Can't invite user because: $error";
      } else {
	print "Invited user whose email is $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

#Build a hash variable to convert string of party names to numbers corresponding to the options in table rwb_opinions
#my %colornumber=('Republican' => 1, 'Democrat' => -1,'Undecided' => 0,);




if ($action eq "give-opinion-data") { 
   if(!UserCan($user,"give-opinion-data")){
     print h2('You do not have the required permission to give your opinion.');
   }
 else{
    $run = param('run');
    my $color = param('party');
 
  #Build a hash variable to convert string of party names to numbers corresponding to the options in table rwb_opinions
my %colornumber=('Republican' => 1, 'Democrat' => -1,'Undecided' => 0,);
    my ($latitude,$longtitude) = (undef,undef);
    #Get the latitude and the longtitude of the voter from cookie 
    if(defined($locationcookie)){
    #And then parse the cookie to get the longtitude and the latitude seperately
          ($latitude,$longtitude) = split(/\//,$locationcookie);

   }
   else{
     print h2("Can't get location from location cookie!");
   }

   if(!$run){
   #create the voting interface
       print start_form(-name=>'Party'),
	h2('Select a Party:'),
           radio_group(-name=>'party',-values=>['Republican','Democrat','Undecided']),
	           hidden(-name=>'run',-default=>['1']),  
                  hidden(-name=>'lat',-default=>[param('lat')]),
                     hidden(-name=>'lng',-default=>[param('lng')]),  
		     
			hidden(-name=>'act',-default=>['give-opinion-data']),
			  submit,
			    end_form,
			      hr;
       print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
    }

   else{

     if(defined($latitude) && defined($longtitude)){
    
        eval { 
	ExecSQL($dbuser,$dbpasswd,"insert into rwb_opinions (submitter,color,latitude,longitude) values (?,?,?,?)",undef,$user,$colornumber{$color},$latitude,$longtitude);};

		print "$user,$colornumber{$color},$latitude,$longtitude";

       print h2("Your opinion is recorded!");

     }

     else{
       print h2("Error!");

     }

  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
  }

}
}

if ($action eq "give-cs-ind-data") { 
  print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}



if($action eq "query-opinion-data"){
  if(!UserCan($user,"query-opinion-data")){
    print h2("You don't have the required permission to query the opinions");
  }

  else{



  }



}




#
# ADD-USER
#
# User Add functionaltiy 
#
#
#
#

if ($action eq "add-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to add users.');
  } else {
    if (!$run) { 
      print start_form(-name=>'AddUser'),
	h2('Add User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      "Email: ", textfield(-name=>'email'),
		p,
		  "Password: ", textfield(-name=>'password'),
		    p,
		      hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['add-user']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
      $error=UserAdd($name,$password,$email,$user);
      if ($error) { 
	print "Can't add user because: $error";
      } else {
	print "Added user $name $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

#
# DELETE-USER
#
# User Delete functionaltiy 
#
#
#
#
if ($action eq "delete-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to delete users.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'DeleteUser'),
	h2('Delete User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['delete-user']),
		  submit,
		    end_form,
		      hr;
    } else {
      my $name=param('name');
      my $error;
      $error=UserDelete($name);
      if ($error) { 
	print "Can't delete user because: $error";
      } else {
	print "Deleted user $name\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# ADD-PERM-USER
#
# User Add Permission functionaltiy 
#
#
#
#
if ($action eq "add-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'AddUserPerm'),
	h2('Add User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['add-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
	print "Can't add permission to user because: $error";
      } else {
	print "Gave user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy 
#
#
#
#
if ($action eq "revoke-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'RevokeUserPerm'),
	h2('Revoke User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['revoke-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
	print "Can't revoke permission from user because: $error";
      } else {
	print "Revoked user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


###////////////////////////////////////////////////////////////////////


#If a person click the link to be invited for the first time, program will lead him/her to the "create account" interface
#and insert the invitee information into the user table and also insert the permission information into the permission table
if($action eq "create-account"){ 
   my $newemail=param('iemail');
   my $permissionstr=param('permissions');
   my $referID = param('referID');
   my @used = eval{ExecSQL($dbuser,$dbpasswd,"select used from rwb_referID where id=?",undef,$referID);};

   my $data = $used[0];
   my $ID_used = @{$data}[0];
	if ($ID_used==1) {
         print h2('This link has already been used to create an account, sorry!');}
   else{

=pod
  my $emailexists;
  eval {$emailexists=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_invited where emailid=?",undef,$newemail);};
 
  
    #my @emailexists;
    #eval{@emailexists=ExecSQL($dbuser,$dbpasswd,"select count(*) from rwb_invited where email=?", undef,$newemail)};
    #$emailreallyexists=@emailexists[0];
 
   if($emailexists){
       print('Error! This user has already been added!');
     }
    else{

	#print "fsdfhj: $newemail";
    eval{ExecSQL($dbuser,$dbpasswd,"insert into rwb_invited values(?)",undef,$newemail)};
=cut
  
    if (!$run) { 
     print start_form(-name=>'Create Account'),
	h2('Create Account'),
	  "Name: ", textfield(-name=>'name'),
	    p,
		  "Password: ", textfield(-name=>'password'),
		    p,
		      hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['create-account']),
                         hidden(-name=>'iemail',-default=>['$newemail']),
                          hidden(-name=>'permissions',-default=>['$permissionstr']),
                           hidden(-name=>'refer',-default=>[param('refer')]),
                           hidden(-name=>'referID',-default=>['$referID']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $referer=param('refer');
      my $password=param('password');
      my $nemail=param('iemail');
      my $permissionstring=param('permissions');
      my @thepermissions=split(/:/,$permissionstring);
      my $permissionst;
	my $encrypt_password = crypt($encrypt, $password);
      #my $item;
      #print "Your password is: $password\n";
      #print "your permissions are $permissionstring\n";
     my $error;
      
      $error=UserAdd($name,$encrypt_password,$nemail,$referer);


      if ($error) { 
	print "Can't create account because: $error";
      } else {
	print "Added user $name as referred by $user\n";
       #eval{ExecSQL($dbuser,$dbpasswd,"insert into rwb_invited values(?)",undef,$newemail);};
      

     my $count=0;
     while($count<@thepermissions){
     # print "permissions are @thepermissions[$count]\n"; 
      $permissionst = @thepermissions[$count];
      GiveUserPerm($name,$permissionst);
      print "\nYour permissions are $permissionst\n";
     #eval{ExecSQL($dbuser,$dbpasswd,"insert into rwb_permissions (name,action) values(?,?)",$name,@thepermissions[$count]);};
      $count++;
     }
     print "Your permissions have been successfully added";
     eval {ExecSQL($dbuser,$dbpasswd,
    "update rwb_referID set used = 1 where id = ?",undef,$referID);};
    }

   
=pod
     foreach (@thepermissions) {
        
        eval{ExecSQL($dbuser,$dbpasswd,"insert into rwb_permissions (name,action) values(?,?)",undef,$name,$_);};
        print "Your permission is: $_";
      }
   
=cut
=pod
      my $error;
      
      $error=UserAdd($name,$password,$nemail,$user);
      if ($error) { 
	print "Can't create account because: $error";
      } else {
	print "Added user $name as referred by $user\n";
       #eval{ExecSQL($dbuser,$dbpasswd,"insert into rwb_invited values(?)",undef,$newemail);};
      }
=cut
    
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

###////////////////////////////////////////////////////////////////////////////

#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
  print hr, p, hr,p, h2('Debugging Output');
  print h3('Parameters');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(param($_)) } param();
  print "</menu>";
  print h3('Cookies');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
  print "</menu>";
  my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
  print h3('SQL');
  print "<menu>";
  for (my $i=0;$i<=$max;$i++) { 
    print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
    print "<li><b>Output:</b> $sqloutput[$i]";
  }
  print "</menu>";
	
	
}

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#

my $CONTRIB_MIN_CT = 25;
#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where cycle IN ($cycle) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
my $cmte_string_rep = BuildQueryStr("cmte_pty_affiliation","or",("'REP'","'R'","'rep'","'Rep'","'GOP'"));
  my @contrib_rep;
  eval { @contrib_rep = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt) from  (cs339.committee_master natural join (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) )where cycle IN ($cycle) and ($cmte_string_rep) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my $cmte_string_dem = BuildQueryStr("cmte_pty_affiliation","or",("'DEM'","'D'","'dem'","'Dem'"));
  my @contrib_dem;
  eval { @contrib_dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from(cs339.committee_master natural join (cs339.comm_to_comm natural join cs339.cmte_id_to_geo) )where cycle IN ($cycle) and ($cmte_string_dem) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my ($data_1,$data_2) = (@contrib_rep[0],@contrib_dem[0]);
  my $contrib_count = @{$data_1}[1] + @{$data_2}[1];
 


 #expand the map
  my $count = 0;
  while ($contrib_count < $CONTRIB_MIN_CT && $count < 10) {
$latne += 0.1;
$latsw -= 0.1;
$longne += 0.1;
$longsw -= 0.1;

eval { @contrib_rep = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.comm_to_cand natural join cs339.cmte_id_to_geo)) where cycle IN ($cycle) and ($cmte_string_rep) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
eval { @contrib_dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.comm_to_cand natural join cs339.cmte_id_to_geo)) where cycle IN ($cycle) and ($cmte_string_dem) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);};

($data_1,$data_2) = (@contrib_rep[0],@contrib_dem[0]);
$contrib_count = @{$data_1}[1] + @{$data_2}[1];
$count++;
}

my $rep_count = @{$data_1}[1];
my $rep_total = @{$data_1}[0];
$rep_total == '' ? ($rep_total = '0') : undef;
my $dem_total = @{$data_2}[0];
my $dem_count = @{$data_2}[1];
$dem_total == '' ? ($dem_total = '0') : undef;
my ($diff,$color) = ($rep_total - $dem_total, 'white');
if ($diff > 0) {
$color = 'red';
} elsif ($diff < 0) {
$color = 'blue';
}
my $text1 = $dem_total;
my $text2 = $rep_total;
PrintHiddenDiv('dem_committee-contributions',$color,$text1);
PrintHiddenDiv('rep_committee-contributions',$color,$text2);
my $text3 = $dem_count;
my $text4 = $rep_count;
PrintHiddenDiv('dem_committee-contributions_count',$color,$text3);
PrintHiddenDiv('rep_committee-contributions_count',$color,$text4);





  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("committee_data","2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("committee_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format,@sqlized) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where cycle IN ($cycle) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("candidate_data", "2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("candidate_data","2D",@rows),$@);
    }
  }
}




#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where cycle IN ($cycle) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  

my $cmte_string_rep = BuildQueryStr("cmte_pty_affiliation","or",("'REP'","'R'","'rep'","'Rep'","'GOP'"));
  my @contrib_rep;
  eval { @contrib_rep = ExecSQL($dbuser, $dbpasswd, "select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.individual natural join cs339.ind_to_geo)) where cycle IN ($cycle) and ($cmte_string_rep) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my $cmte_string_dem = BuildQueryStr("cmte_pty_affiliation","or",("'DEM'","'D'","'dem'","'Dem'"));
  my @contrib_dem;
  eval { @contrib_dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.individual natural join cs339.ind_to_geo)) where cycle IN ($cycle) and ($cmte_string_dem) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my ($data_1,$data_2) = (@contrib_rep[0],@contrib_dem[0]);
  my $contrib_count = @{$data_1}[1] + @{$data_2}[1];
  
  my $count = 0;
  while ($contrib_count < $CONTRIB_MIN_CT && $count < 10) {
$latne += 0.1;
$latsw -= 0.1;
$longne += 0.1;
$longsw -= 0.1;

eval { @contrib_rep = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.individual natural join cs339.ind_to_geo)) where cycle IN ($cycle) and ($cmte_string_rep) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
eval { @contrib_dem = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt), count(transaction_amnt) from (cs339.committee_master natural join (cs339.individual natural join cs339.ind_to_geo))) where cycle IN ($cycle) and ($cmte_string_dem) and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

($data_1,$data_2) = (@contrib_rep[0],@contrib_dem[0]);
$contrib_count = @{$data_1}[1] + @{$data_2}[1];
$count++;
}

my $rep_total = @{$data_1}[0];
my $rep_count = @{$data_1}[1];
$rep_total == '' ? ($rep_total = '0') : undef;
my $dem_total = @{$data_2}[0];
my $dem_count = @{$data_2}[1];
$dem_total == '' ? ($dem_total = '0') : undef;
my ($diff,$color) = ($rep_total - $dem_total, 'white');
if ($diff > 0) {
$color = 'red';
} elsif ($diff < 0) {
$color = 'blue';
}
my $text1 = $dem_total;
my $text2 = $rep_total;
PrintHiddenDiv('dem_individual-contributions',$color,$text1);
PrintHiddenDiv('rep_individual-contributions',$color,$text2);
my $text3 = $dem_count;
my $text4 = $rep_count;
PrintHiddenDiv('dem_individual-contributions_count',$color,$text3);
PrintHiddenDiv('rep_individual-contributions_count',$color,$text4);


  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("individual_data", "2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("individual_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
  my ($latne,$longne,$latsw,$longsw,$cyclefrom,$cycleto,$cycles,$format) = @_;

  my @rows;
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };

  my @opinions_rep;
  eval { @opinions_rep = ExecSQL($dbuser, $dbpasswd, "select sum(color), count(color) from rwb_opinions where color=1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my @opinions_dem;
  eval { @opinions_dem = ExecSQL($dbuser,$dbpasswd,"select sum(color), count(color) from rwb_opinions where color=-1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  
  my ($data_1,$data_2) = (@opinions_rep[0],@opinions_dem[0]);
  my $contrib_count = @{$data_1}[1] + @{$data_2}[1];

#
###################################################
#expand the map###################################
  
  my $count = 0;
  while ($contrib_count < $CONTRIB_MIN_CT && $count < 10) {
$latne += 0.1;
$latsw -= 0.1;
$longne += 0.1;
$longsw -= 0.1;

eval { @opinions_rep = ExecSQL($dbuser, $dbpasswd, "select sum(color), count(color) from rwb_opinions where color=1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
eval { @opinions_dem = ExecSQL($dbuser,$dbpasswd,"select sum(color), count(color) from rwb_opinions where color=-1 and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };

##assign the value selected

($data_1,$data_2) = (@opinions_rep[0],@opinions_dem[0]);
$contrib_count = @{$data_1}[1] + @{$data_2}[1];
$count++;
}

my $rep_total = @{$data_1}[0];
$rep_total == '' ? ($rep_total = '0') : undef;
my $dem_total = -@{$data_2}[0];
$dem_total == '' ? ($dem_total = '0') : undef;

##see if what color shoud the background be
my ($diff,$color) = ($rep_total - $dem_total, 'white');
if ($diff > 0) {
$color = 'red';
} elsif ($diff < 0) {
$color = 'blue';
}

my @stats;
eval { @stats = ExecSQL($dbuser, $dbpasswd, "select avg(color), stddev(color) from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
my $data_3 = @stats[0];
my $avg = @{$data_3}[0];
my $stddev = @{$data_3}[1];

PrintHiddenDiv('h_rep_o',$color,$rep_total);
PrintHiddenDiv('h_dem_o',$color,$dem_total);
PrintHiddenDiv('h_std',$color,$avg);
PrintHiddenDiv('h_avg',$color,$stddev);
  
  if ($@) {
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("opinion_data","2D",
["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
@rows),$@);
    } else {
      return (MakeRaw("opinion_data","2D",@rows),$@);
    }
  }
}

###//////////////////////////////////////////////////////////////////////////////////

#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("perm_table",
		      "2D",
		     ["Perm"],
		     @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("user_table",
		      "2D",
		     ["Name", "Email"],
		     @rows),$@);
  }
}
###////////////////////////////////////////////////////////////////////////////////


#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("userperm_table",
		      "2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}


###////////////////////////////////////////////////////////////////////////////////////

#Invite user
sub UserInvite {
my $referID=int(rand(10000));
print "referID is $referID";
my $used=0;
my ($email,@inpermission) = @_;
my $count=0;
my $permissionstr="";


while($count<@inpermission){
$permissionstr=$permissionstr.@inpermission[$count].":";
$count++;
}

my $link = "http://murphy.wot.eecs.northwestern.edu/~xto633/rwb/rwb.pl?act=create-account&refer=$user&iemail=$email&permissions=$permissionstr&referID=$referID";
eval{ExecSQL($dbuser,$dbpasswd, "insert into rwb_referID(id,used) values (?,?)", undef, $referID,$used );};
my $subject = "Create-Account";
my $content = "Click the following link to your account: " .$link;



open(MAIL,"| mail -s $subject $email") or die "Can't run mail\n";

print MAIL $content;

close(MAIL);	


}







###///////////////////////////////////////////////////////////////////////////////








#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
# 
# UserAdd($name,$password,$email)
#
sub UserAdd { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_users (name,password,email,referer) values (?,?,?,?)",undef,@_);};
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);};
  return $@;
}


####//////////////////////////////////////////////////////////////

sub GetUserPerm{
my ($getname)=@_;
my @getpermission;
eval{@getpermission=ExecSQL($dbuser,$dbpasswd,"select action from rwb_permissions where name=?","COL",$getname);};
return @getpermission;
}
###//////////////////////////////////////////////////////////////


#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_permissions (name,action) values (?,?)",undef,@_);};
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "delete from rwb_permissions where name=? and action=?",undef,@_);};
  return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user,$password)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where name=? and password=?","COL",$user,$password);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}


#
#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}





#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    $out="<table id=\"$id\" border>";
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
# Delete a user
# Delete a user
# Delete a user
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}


######################################################################
#
# Nothing important after this
#
# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

#to process the string for queries
sub BuildQueryStr {
my ($colname,$sep,@elems) = @_;
my $out = "";
foreach (@elems) {
$out .= "$colname=$_ $sep ";
}
return (substr $out, 0, -(length($sep)+2));
}

sub PrintHiddenDiv {
my ($id,$color,$text) = @_;
print "<div id='$id' color='$color' style='display:none;'>$text</div>";
}
