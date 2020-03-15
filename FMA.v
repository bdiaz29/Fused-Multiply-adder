`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2019 08:10:43 AM
// Design Name: 
// Module Name: FMA
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module FMA(input [31:0] floatA,floatB,floatC,output [31:0] outFloat);
wire[56:0] product;
wire [106:0] sum;
mult m(floatA,floatB,product);
add a(product,floatC,sum);
round r(sum,outFloat);
endmodule



module mult(input [31:0] A,B, output [56:0] multOut);
//take the exponents
wire [8:0] expA, expB;

assign expA[8]=0;
assign expB[8]=0;
assign expA[7:0]=A[30:23];
assign expB[7:0]=B[30:23];
//take mantissas 
//first zero padding
wire [47:0] MA, MB;
assign MA[47:24]=0;
assign MB[47:24]=0;

//take mantissas
assign MA[22:0]=A[22:0];
assign MB[22:0]=B[22:0];
//assign lead digit 
assign MA[23]=~(expA==0);
assign MB[23]=~(expB==0);


wire[47:0] multM;
assign multM=MA*MB;

//mask to pass value
wire overflow;
wire underflow;
wire [47:0]overflow_mask;
wire [47:0]underflow_mask;
wire [7:0]expOverflow_mask;
wire [7:0]expUnderflow_mask;
assign overflow_mask={48{overflow}};
assign underflow_mask={48{~underflow}};

assign expOverflow_mask={8{overflow}};
assign expUnderflow_mask={8{~underflow}};

assign overflow=((expA+expB)>9'd382);//127+255=382
assign underflow=((expA+expB)<9'd104);//127-23=104
//calculate exponents
wire [8:0] expAdd;
assign expAdd=(expA+expB)-9'd126;
wire [7:0] multExp;
assign multExp=expAdd[7:0];
wire multSign;
assign multSign=A[31]^B[31];

//final steps
wire finalMultS;
wire[7:0] finalMultExp;
wire[47:0] finalMultM;

assign finalMultS=multSign;
assign finalMultExp=(multExp&expUnderflow_mask)|expOverflow_mask;
assign finalMultM=(multM&underflow_mask)|overflow_mask;


assign multOut[56]=finalMultS;
assign multOut[55:48]=finalMultExp;
assign multOut[47:0]=finalMultM;

//construct multiplier output 
//build output 

endmodule











module add(input [56:0] product,input [31:0] C,output[106:0] addOut);
//take signs
wire sc,sp;
assign sp=product[56];
assign sc=C[31];
wire [7:0] expP ,expC;
assign expP=product[55:48];
assign expC=C[30:23];
//take mantissas
wire[48:0] MP;
assign MP[47:0]=product[47:0];
wire[48:0] MC;
assign MC[47]=~(expC==0);
assign MC[46:24]=C[22:0];
assign MC[23:0]=0;
//extra padding at the end
assign MC[48]=0;
assign MP[48]=0;

//determine which exponent is bigger
wire bigger;
assign bigger=(expP>=expC);
wire [47:0] bigM,smallM;
wire [7:0] bigExp,smallExp;
wire bigS,smallS;
assign bigM=(MP&({49{bigger}}))|(MC&({49{~bigger}}));
assign smallM=(MP&({49{~bigger}}))|(MC&({49{bigger}}));

assign bigExp=(expP&({8{bigger}}))|(expC&({8{~bigger}}));
assign smallExp=(expP&({8{~bigger}}))|(expC&({8{bigger}}));

assign bigS=(sp&({1{bigger}}))|(sc&({1{~bigger}}));
assign smallS=(sp&({1{~bigger}}))|(sc&({1{bigger}}));

//determine difference in exponents
wire [7:0] expDifference;
assign expDifference=bigExp-smallExp;


//assign to stages
wire [97:0] bigM_stage1;
wire [97:0] smallM_stage1;
assign bigM_stage1[95:48]=bigM;
assign smallM_stage1[95:48]=smallM;
//zero padding
assign bigM_stage1[97:96]=0;
assign smallM_stage1[97:96]=0;
assign bigM_stage1[47:0]=0;
assign smallM_stage1[47:0]=0;
//next stage
wire [97:0] bigM_stage2;
wire [97:0] smallM_stage2;
assign bigM_stage2=bigM_stage1;
assign smallM_stage2=smallM_stage1>>expDifference;
//next stage adding 2s compliment
wire[97:0] signedSum;
wire[97:0] signedTop,signedBottom;
assign signedTop=((bigM_stage2^{98{bigS}})+bigS);
assign signedBottom=((smallM_stage2^{98{smallS}})+smallS);
//adding top to bottom
assign signedSum=signedTop+signedBottom;
wire sumSign;
assign sumSign=signedSum[97];
//find absolute value of product 
wire[97:0] absSum;
assign absSum=((signedSum^{98{sumSign}})+sumSign);
//create masks
//first transger expBig to 2scompliment friendly expansion
wire [8:0] exp;
assign exp[7:0]=bigExp;
assign exp[8]=0;
wire overflow;
wire underflow;
wire [97:0]overflow_mask;
wire [97:0]underflow_mask;
wire [7:0]expOverflow_mask;
wire [7:0]expUnderflow_mask;
assign overflow=(bigExp+absSum[96])>9'd255;
assign underflow=((bigExp==0)&&(absSum[95:72]==0));

assign overflow_mask={98{overflow}};
assign underflow_mask={98{~underflow}};

assign expOverflow_mask={8{overflow}};
assign expUnderflow_mask={8{~underflow}};
//take final sum
wire[97:0] fSum;
assign fSum=absSum<<(1+absSum[96]);////left shift by one since sign no longer needed and an additional one if increase one digit
wire[7:0] fExp;
assign fExp=bigExp+absSum[96];
wire fSign;
assign fSign=sumSign;

wire [97:0] maskedM;
wire [7:0]maskedExp;
wire maskedS;
assign  maskedM=(fSum&underflow_mask)|overflow_mask;
assign  maskedExp=(fExp&expUnderflow_mask)|expOverflow_mask;
assign  maskedS=fSign;


//construct output
assign addOut[106]=fSign;
assign addOut[105:98]=maskedExp;
assign addOut[97:0]=maskedM;


endmodule

module round(input [106:0] addOut,output [31:0] roundedFloat);
//extract sign
wire s;
assign s=addOut[106];
//extract exponent
wire[7:0] exp;
assign exp=addOut[105:98];
//create 2s compliment ex number for exponent math
wire [8:0] ex;
assign ex[7:0]=exp;
assign ex[8]=0;
//extract mantissa
wire [97:0] m;
assign m=addOut[97:0];
//normalization
wire firstTwoOne;
assign firstTwoOne=(m[96]|m[95]);
wire [7:0] z;
wire [97:0] endShifted,expShifted;
countZeroes zed(m,z);
assign endShifted=m<<(z);
assign expShifted=m<<(exp);
//determine if it needs a shift 
wire needshift;

//determine type of shift
//1 for endshifted 0 for expshifted 
//wire typeShift;
//assign typeShift=((zeroes-(exp+9'd126))>9'd126);
wire expLargerThanZ;
assign needshift=((~firstTwoOne)&&~expLargerThanZ)|(exp==0);
assign expLargerThanZ=((ex)>=z);
wire [7:0] expdiff;
assign expdiff=ex-z;

reg [7:0] exponent;

reg [22:0]M;
always@(*)
begin
if(needshift)
begin 
 if(expLargerThanZ)begin M=endShifted[97:75];exponent=expdiff+1;  end
  else begin M=expShifted[95:73]; exponent=0; end
end 
else if (m[97]) begin M=m[96:74]; exponent=exp+1;end
else if (m[96])begin M=m[95:73]; exponent=exp;end
else begin M=m[94:72]; exponent=exp-1;end



end

assign roundedFloat[31]=s;
assign roundedFloat[22:0]=M;
assign roundedFloat[30:23]=exponent;
//if exp larger than z then endshifted
//if exp smaller than z than expshifted




//mask to handle overflow and underflow
//assign overflow=(bigExp+absSum[96])>9'd255;
//assign underflow=~((bigExp==0)&&(absSum[95:72]==0));

//assign overflow_mask={98{overflow}};
//assign underflow_mask={98{underflow}};

//assign expOverflow_mask={8{overflow}};
//assign expUnderflow_mask={8{underflow}};

endmodule 

//counts the number of zeroes from left to right 
//for rest change input 
module countZeroes(input [97:0] m,output [7:0] zeroes);
//26

reg [7:0] count;
assign zeroes=count;
always@(*)
begin
if(m[97])begin count=8'd0; end
else if(m[96])begin count=8'd1;end
else if(m[95])begin count=8'd2;end
else if(m[94])begin count=8'd3;end
else if(m[93])begin count=8'd4;end
else if(m[92])begin count=8'd5;end
else if(m[91])begin count=8'd6;end
else if(m[90])begin count=8'd7;end
else if(m[89])begin count=8'd8;end
else if(m[88])begin count=8'd9;end
else if(m[87])begin count=8'd10;end
else if(m[86])begin count=8'd11;end
else if(m[85])begin count=8'd12;end
else if(m[84])begin count=8'd13;end
else if(m[83])begin count=8'd14;end
else if(m[82])begin count=8'd15;end
else if(m[81])begin count=8'd16;end
else if(m[80])begin count=8'd17;end
else if(m[79])begin count=8'd18;end
else if(m[78])begin count=8'd19;end
else if(m[77])begin count=8'd20;end
else if(m[76])begin count=8'd21;end
else if(m[75])begin count=8'd22;end
else if(m[74])begin count=8'd23;end
else if(m[73])begin count=8'd24;end
else if(m[72])begin count=8'd25;end
else if(m[71])begin count=8'd26;end
else if(m[70])begin count=8'd27;end
else if(m[69])begin count=8'd28;end
else if(m[68])begin count=8'd29;end
else if(m[67])begin count=8'd30;end
else if(m[66])begin count=8'd31;end
else if(m[65])begin count=8'd32;end
else if(m[64])begin count=8'd33;end
else if(m[63])begin count=8'd34;end
else if(m[62])begin count=8'd35;end
else if(m[61])begin count=8'd36;end
else if(m[60])begin count=8'd37;end
else if(m[59])begin count=8'd38;end
else if(m[58])begin count=8'd39;end
else if(m[57])begin count=8'd40;end
else if(m[56])begin count=8'd41;end
else if(m[55])begin count=8'd42;end
else if(m[54])begin count=8'd43;end
else if(m[53])begin count=8'd44;end
else if(m[52])begin count=8'd45;end
else if(m[51])begin count=8'd46;end
else if(m[50])begin count=8'd47;end
else if(m[49])begin count=8'd48;end
else if(m[48])begin count=8'd49;end
else if(m[47])begin count=8'd50;end
else if(m[46])begin count=8'd51;end
else if(m[45])begin count=8'd52;end
else if(m[44])begin count=8'd53;end
else if(m[43])begin count=8'd54;end
else if(m[42])begin count=8'd55;end
else if(m[41])begin count=8'd56;end
else if(m[40])begin count=8'd57;end
else if(m[39])begin count=8'd58;end
else if(m[38])begin count=8'd59;end
else if(m[37])begin count=8'd60;end
else if(m[36])begin count=8'd61;end
else if(m[35])begin count=8'd62;end
else if(m[34])begin count=8'd63;end
else if(m[33])begin count=8'd64;end
else if(m[32])begin count=8'd65;end
else if(m[31])begin count=8'd66;end
else if(m[30])begin count=8'd67;end
else if(m[29])begin count=8'd68;end
else if(m[28])begin count=8'd69;end
else if(m[27])begin count=8'd70;end
else if(m[26])begin count=8'd71;end
else if(m[25])begin count=8'd72;end
else if(m[24])begin count=8'd73;end
else if(m[23])begin count=8'd74;end
else if(m[22])begin count=8'd75;end
else if(m[21])begin count=8'd76;end
else if(m[20])begin count=8'd77;end
else if(m[19])begin count=8'd78;end
else if(m[18])begin count=8'd79;end
else if(m[17])begin count=8'd80;end
else if(m[16])begin count=8'd81;end
else if(m[15])begin count=8'd82;end
else if(m[14])begin count=8'd83;end
else if(m[13])begin count=8'd84;end
else if(m[12])begin count=8'd85;end
else if(m[11])begin count=8'd86;end
else if(m[10])begin count=8'd87;end
else if(m[9])begin count=8'd88;end
else if(m[8])begin count=8'd89;end
else if(m[7])begin count=8'd90;end
else if(m[6])begin count=8'd91;end
else if(m[5])begin count=8'd92;end
else if(m[4])begin count=8'd93;end
else if(m[3])begin count=8'd94;end
else if(m[2])begin count=8'd95;end
else if(m[1])begin count=8'd96;end
else if(m[0])begin count=8'd97;end
else begin count=8'd98; end 
end
endmodule