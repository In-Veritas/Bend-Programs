// Retired (Bend 2.0.40 port). This script used to derive hub-private copies
// of every standalone demo under bendjogos_web/modules/, because the old
// Bend3 merged all imports into one global declaration book and `as Alias`
// was not a namespace. In Bend 2.0.40 an import alias is a real namespace,
// so web_bendjogos.bend imports each standalone source directly
// (`import ../tictactoe_web/web_tictactoe.bend as Tic`, ...) and modules/
// was deleted. Kept as a no-op so old scripts that call it still succeed.
console.log("generate_modules.mjs: retired; the hub imports the standalone demos directly.");
