#!/usr/bin/env rdmd

import core.thread : Thread;
import core.time : dur;
import std.array : appender;
import std.algorithm : map;
import std.ascii : digits, letters;
import std.conv : to;
import std.random : uniform;
import std.range : iota;
import std.regex : regex, split;
import std.stdio :  File, writef, writefln, writeln;
import std.socket : InternetAddress, TcpSocket;
import undead.socketstream : SocketStream;

class Image : Thread
	{
	
	string
		DOMAIN		= "i.imgur.com",
		EXT			= ".jpg",
		PROTOCOL	= "http://";
	
	string destination;
	void delegate( bool ) counter;
	
	this( string destination, void delegate( bool ) counter )
		{
		Image.destination	= destination;
		Image.counter		= counter;
		super( &run );
		}
	
	private void run()
		{
		char[][] line;
		string ext, name;
		string collection	= digits ~ letters;
		auto appname		= appender!string();
		TcpSocket tcp		= new TcpSocket( new InternetAddress( DOMAIN, 80 ) );
		SocketStream socket = new SocketStream( tcp );
		foreach( char c; iota( uniform( 5, 8 ) ).map!( _ => collection[ uniform( 0, $ ) ] ) )
			{
			appname.put( c );
			}
		name = appname.data();
		socket.writeString( "GET " ~ PROTOCOL ~ DOMAIN ~ "/" ~ name ~ EXT ~ " HTTP/1.0\r\nHost: " ~ DOMAIN ~ "\r\n\r\n" );
		do
			{
			line = split( socket.readLine(), regex( ": *" ) );
			if( line )
				{
				if( line[ 0 ] == "HTTP/1.0 404 Not Found" )
					{
					writefln( "Image %s was not found", name );
					socket.close();
					break;
					}
				else if( line[ 0 ] == "Content-Length" && line[ 1 ] == "503" )
					{
					writefln( "Image %s does not exists or no longer available", name );
					socket.close();
					break;
					}
				else if( line[ 0 ] == "Content-Type" )
					{
					ext = cast(string)( split( line[ 1 ], regex( "image/*" ) )[ 1 ] );
					}
				}
			}
		while( line.length );
		if( socket.readable )
			{
			writefln( "Image %s.%s was found", name, ext );
			auto file = File( destination ~ "/" ~ name, "w" );
			while( !socket.eof() )
				{
				file.write( socket.getc() );
				}
			counter( true );
			}
		else
			{
			counter( false );
			}
		}
	}
	
class Init : Thread
	{
	
	string destination;
	
	int attempts_count, attempts_max, downloads_count, downloads_max, time_count, time_interval;
	
	void delegate( bool ) counterDelegate;
	
	this( string destination, int attempts, int downloads, int interval )
		{
		Init.destination	= destination;
		attempts_max		= attempts;
		downloads_max		= downloads;
		time_interval		= interval;
		counterDelegate		= &counter;
		super( &run );
		}
	
	void counter( bool download )
		{
		if( download )
			{
			++downloads_count;
			}
		if( ( attempts_max && attempts_count == attempts_max ) || ( downloads_max && downloads_count == downloads_max ) )
			{
			writefln( "%d attempts and %d images downloaded within %d seconds", attempts_count, downloads_count, time_count );
			}
		}
	
	private void run()
		{
		time_count++;
		writef( "Attempt %d. ", ++attempts_count );
		Thread image = new Image( destination, counterDelegate );
		image.start();
		if( ( attempts_max && attempts_count < attempts_max ) && ( downloads_max && downloads_count < downloads_max ) )
			{
			sleep( dur!( "seconds" )( time_interval ) );
			run();
			}
		}
	
	}

void main( string[] args )
	{
	Thread init = new Init( args[ 1 ], to!int( args[ 2 ] ), to!int( args[ 3 ] ), to!int( args[ 4 ] ) );
	init.start();
	}
