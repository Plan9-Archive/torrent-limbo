Torrentget: module {
	init:	fn(nil: ref Draw->Context, args: list of string);

	Dialersmax:	con 5;  # max number of dialer procs
	Dialtimeout:	con 20;  # timeout for connecting to peer
	Peersmax:	con 80;
	Peersdialedmax:	con 40;
	Piecesrandom:	con 4;  # count of first pieces in a download to pick at random instead of rarest-first
	Blocksize:	con 16*1024;  # block size of blocks we request
	Blockqueuemax:	con 100;  # max number of Requests a peer can queue at our side without being considered bad
	Blockqueuesize:	con 30;  # number of pending blocks to request to peer
	Diskchunksize:	con 128*1024;  # do initial write to disk for any block/piece of this size, to prevent fragmenting the file system
	Batchsize:	con Diskchunksize/Blocksize;
	Netiounit:	con 1500-20-20;  # typical network data io unit, ethernet-ip-tcp

	Peeridlen:	con 20;

	Listenhost:	con "*";
	Listenport:	con 6881;
	Listenportrange:	con 100;

	Intervalmin:	con 30;
	Intervalmax:	con 24*3600;
	Intervalneed:	con 10;  # when we need more peers during startup period
	Intervaldefault:	con 1800;
	Intervalstartupperiod:	con 120;

	Blocksizemax:	con 32*1024;  # max block size allowed for incoming blocks
	Unchokedmax:	con 4;
	Seedunchokedmax:	con 4;
	Ignorefaultyperiod:	con 300;
};

Misc: module {
	PATH:	con "/dis/lib/bittorrent/misc.dis";

	init:	fn(randmod: Rand);

	randomize:	fn[T](a: array of T);
	sort:		fn[T](a: array of T, cmp: ref fn(a, b: T): int);

	readfile:	fn(f: string): (string, string);
	readfd:	fn(fd: ref Sys->FD): (array of byte, string);
	hex:	fn(d: array of byte): string;
	l2a:	fn[T](l: list of T): array of T;
};

Pools: module {
	PATH:	con "/dis/lib/bittorrent/pools.dis";

	PoolRandom, PoolRotateRandom, PoolInorder: con iota;  # pool mode

	init:	fn(randmod: Rand);

	Pool: adt[T] {
		active:	array of T;
		pool:	array of T;
		poolnext:	int;
		mode:	int;

		new:	fn(mode: int): ref Pool[T];
		fill:	fn(p: self ref Pool);
		take:	fn(p: self ref Pool): T;
		pooladd:	fn(p: self ref Pool, e: T);
		pooladdunique:	fn(p: self ref Pool, e: T);
		poolhas:	fn(p: self ref Pool, e: T): int;
		pooldel:	fn(p: self ref Pool, e: T);
		text:	fn(p: self ref Pool): string;
	};
};

Rate: module {
	PATH:	con "/dis/lib/bittorrent/rate.dis";

	TrafficHistorysize:	con 10;

	init:	fn();

	Traffic: adt {
		last:	int;  # last element in `d' that may have been used
		d:	array of (int, int);  # time, bytes
		winsum:	int;
		sum:	big;
		npackets:	int;
		starttime:	int;

		new:	fn(): ref Traffic;
		add:	fn(t: self ref Traffic, bytes: int);
		packet:	fn(t: self ref Traffic);
		rate:	fn(t: self ref Traffic): int;
		total:	fn(t: self ref Traffic): big;
		text:	fn(t: self ref Traffic): string;
	};
};


Pieces: module {
	PATH:	con "/dis/lib/bittorrent/pieces.dis";

	init:	fn();

	Piece: adt {
		hashstate:	ref Keyring->DigestState;
		hashstateoff:	int;
		index:	int;
		have:	ref Bitarray->Bits;
		length:	int;
		busy:	array of (int, int);  # peerid, peerid
		done:	array of int;  # peerid

		new:	fn(index, length: int): ref Piece;
		isdone:	fn(p: self ref Piece): int;
		orphan:	fn(p: self ref Piece): int;
		hashadd:	fn(p: self ref Piece, buf: array of byte);
		text:	fn(p: self ref Piece): string;
	};

	Block: adt {
		piece, begin, length:	int;

		new:	fn(piece, begin, length: int): ref Block;
		eq:	fn(b1, b2: ref Block): int;
		text:	fn(b: self ref Block): string;
	};


	pieces:	list of ref Piece;  # only active pieces

	piecenew:	fn(index, length: int): ref Piece;
	piecedel:	fn(p: ref Piece);
	piecefind:	fn(index: int): ref Piece;

	blockhave:	fn(l: list of ref Block, b: ref Block): int;
	blockdel:	fn(l: list of ref Block, b: ref Block): list of ref Block;
	blocktake:	fn(l: list of ref Block): (list of ref Block, ref Block);
};



Peers: module {
	PATH:	con "/dis/lib/bittorrent/peers.dis";

	# Peer.state
	RemoteChoking, RemoteInterested, LocalChoking, LocalInterested: con (1<<iota);

	init:	fn(randmod: Rand);


	Newpeer: adt {
		addr:   string;
		ip:     string;
		peerid: array of byte;  # may be nil, for incoming connections or compact track responses

		text:   fn(np: self Newpeer): string;
	};

	Peer: adt {
		id:	int;
		np:	Newpeer;
		fd:	ref Sys->FD;
		extensions, peerid: array of byte;
		peeridhex:	string;
		outmsgs:	chan of ref Bittorrent->Msg;
		reqs:	ref Requests->Reqs;
		piecehave:	ref Bitarray->Bits;
		state:	int;
		msgseq:	int;
		up, down, metaup, metadown: ref Rate->Traffic;
		wants:	list of ref Pieces->Block;
		netwriting:	int;
		lastunchoke:	int;
		dialed:	int;
		buf:	ref Buf;

		new:	fn(np: Newpeer, fd: ref Sys->FD, extensions, peerid: array of byte, dialed: int, npieces: int): ref Peer;
		remotechoking:	fn(p: self ref Peer): int;
		remoteinterested:	fn(p: self ref Peer): int;
		localchoking:	fn(p: self ref Peer): int;
		localinterested:	fn(p: self ref Peer): int;
		isdone:	fn(p: self ref Peer): int;
		text:	fn(p: self ref Peer): string;
		fulltext:	fn(p: self ref Peer): string;
	};

	Buf: adt {
		data:	array of byte;
		piece:	int;
		pieceoff:	int;
		piecelength:	int;

		new:	fn(): ref Buf;
		tryadd:	fn(b: self ref Buf, piece: ref Pieces->Piece, begin: int, buf: array of byte): int;
		isfull:	fn(b: self ref Buf): int;
		clear:	fn(b: self ref Buf);
		overlaps:	fn(b: self ref Buf, piece, begin, end: int): int;
	};


	trackerpeers:   list of Newpeer;  # peers we are not connected to

	trackerpeerdel:	fn(np: Newpeer);
	trackerpeeradd:	fn(np: Newpeer);
	trackerpeertake:	fn(): Newpeer;


	peers:	list of ref Peer;  # peers we are connected to
	luckypeer:	ref Peer;

	peerconnected:	fn(addr: string): int;
	peerdel:	fn(peer: ref Peer);
	peeradd:	fn(p: ref Peer);
	peerknownip:	fn(ip: string): int;
	peerhas:	fn(p: ref Peer): int;
	peersdialed:	fn(): int;
	peerfind:	fn(id: int): ref Peer;
	peersunchoked:	fn(): list of ref Peer;
	peersactive:	fn(): list of ref Peer;
};

Requests: module {
	PATH:	con "/dis/lib/bittorrent/requests.dis";

	init:	fn();

	Req: adt {
		pieceindex, blockindex, cancelled: int;

		new:	fn(pieceindex, blockindex: int): Req;
		eq:	fn(r1, r2: Req): int;
		text:	fn(r: self Req): string;
	};

	Reqs: adt {
		a:	array of Req;
		first, next:	int;
		lastreq:	ref Req;

		new:	fn(size: int): ref Reqs;
		take:	fn(r: self ref Reqs, req: Req): int;
		add:	fn(r: self ref Reqs, req: Req);
		peek:	fn(r: self ref Reqs): Req;
		cancel:	fn(r: self ref Reqs, req: Req);
		flush:	fn(r: self ref Reqs);
		last:	fn(r: self ref Reqs): ref Req;
		isempty:	fn(r: self ref Reqs): int;
		isfull:		fn(r: self ref Reqs): int;
		count:	fn(r: self ref Reqs): int;
		size:	fn(r: self ref Reqs): int;
		text:	fn(r: self ref Reqs): string;
	};

	Batch: adt {
		blocks:	array of int;
		piece:	ref Pieces->Piece;

		new:	fn(first, n: int, piece: ref Pieces->Piece): ref Batch;
		unused:	fn(b: self ref Batch): list of Req;
		usedpartial:	fn(b: self ref Batch, peer: ref Peers->Peer): list of Req;
		text:	fn(b: self ref Batch): string;
	};

	batches:	fn(p: ref Pieces->Piece): array of ref Batch;
};

Verify: module {
	PATH:	con "/dis/lib/bittorrent/verify.dis";

	init:	fn();

	chunkreader:	fn(fds: list of ref (ref Sys->FD, big), reqch: chan of ref (int, big, chan of (array of byte, string)));
	piecehash:	fn(fds: list of ref (ref Sys->FD, big), piecelen: int, p: ref Pieces->Piece): (array of byte, string);
};
