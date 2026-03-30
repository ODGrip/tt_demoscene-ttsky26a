module tt_um_odgrip_demoscene_ttsky26a (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // VGA 640x480 @ ~60 Hz con clock ~25 MHz
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] hcount;
    reg [9:0] vcount;
    reg [15:0] frame;

    wire visible;
    wire hsync;
    wire vsync;

    // Coordinate ridotte per alleggerire il rendering
    wire [7:0] x;
    wire [7:0] y;
    wire [7:0] t;

    // Sfondo
    wire pat0;
    wire pat1;
    wire pat2;
    wire [1:0] bg_r;
    wire [1:0] bg_g;
    wire [1:0] bg_b;

    // Centro logo
    wire [7:0] cx;
    wire [7:0] cy;

    // Coordinate relative signed
    wire signed [9:0] dx;
    wire signed [9:0] dy;

    // Cerchio
    wire [19:0] dx2;
    wire [19:0] dy2;
    wire [19:0] dist2;
    wire ring;
    wire circle_fill;

    // Lettere
    wire t_top_bar;
    wire t_top_stem;
    wire t_top;

    wire t_bot_bar;
    wire t_bot_stem;
    wire t_bot;

    wire in_t;

    // Colori finali
    wire [1:0] mix_r;
    wire [1:0] mix_g;
    wire [1:0] mix_b;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;

    assign visible = (hcount < H_VISIBLE) && (vcount < V_VISIBLE);

    // Sync attivi bassi
    assign hsync = ~((hcount >= (H_VISIBLE + H_FRONT)) &&
                     (hcount <  (H_VISIBLE + H_FRONT + H_SYNC)));

    assign vsync = ~((vcount >= (V_VISIBLE + V_FRONT)) &&
                     (vcount <  (V_VISIBLE + V_FRONT + V_SYNC)));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hcount <= 10'd0;
            vcount <= 10'd0;
            frame  <= 16'd0;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                hcount <= 10'd0;
                if (vcount == V_TOTAL - 1) begin
                    vcount <= 10'd0;
                    frame  <= frame + 16'd1;
                end else begin
                    vcount <= vcount + 10'd1;
                end
            end else begin
                hcount <= hcount + 10'd1;
            end
        end
    end

    assign x = hcount[9:2];   // 0..159 circa
    assign y = vcount[9:2];   // 0..119 circa
    assign t = frame[9:2];

    // Sfondo animato
    assign pat0 = x[4] ^ y[4] ^ t[3];
    assign pat1 = x[5] ^ y[3] ^ t[4];
    assign pat2 = x[3] ^ y[5] ^ t[2];

    assign bg_r = {pat0, x[4] ^ t[2]};
    assign bg_g = {pat1, y[4] ^ t[3]};
    assign bg_b = {pat2, x[5] ^ y[5]};

    // Logo fermo al centro se ui_in[1] = 1
    // Altrimenti si muove lentamente
    assign cx = ui_in[1] ? 8'd80 : (8'd80 + {2'b00, t[5:0]} - 8'd32);
    assign cy = ui_in[1] ? 8'd60 : (8'd60 + {3'b000, t[4:0]} - 8'd16);

    // Coordinate relative
    assign dx = $signed({1'b0, x}) - $signed({1'b0, cx});
    assign dy = $signed({1'b0, y}) - $signed({1'b0, cy});

    // Distanza quadrata dal centro
    assign dx2 = dx * dx;
    assign dy2 = dy * dy;
    assign dist2 = dx2 + dy2;

    // Bordo nero del cerchio e riempimento bianco
    // r esterno ~30, r interno ~24
    assign ring        = (dist2 <= 20'd899) && (dist2 >= 20'd576);
    assign circle_fill = (dist2 < 20'd576);

    // T superiore: più spessa
    assign t_top_bar =
        (y >= (cy - 10'd17)) && (y < (cy - 10'd10)) &&
        (x >= (cx - 10'd22)) && (x < (cx + 10'd10));

    assign t_top_stem =
        (y >= (cy - 10'd16)) && (y < (cy + 10'd10)) &&
        (x >= (cx - 10'd10))  && (x < (cx + 10'd0));

    assign t_top = t_top_bar || t_top_stem;

    // T inferiore/destra: più spessa
    assign t_bot_bar =
        (y >= (cy - 10'd2))  && (y < (cy + 10'd6)) &&
        (x >= (cx - 1'd10)) && (x < (cx + 10'd21));

    assign t_bot_stem =
        (y >= (cy + 10'd2))  && (y < (cy + 10'd26)) &&
        (x >= (cx + 10'd7))  && (x < (cx + 10'd15));

    assign t_bot = t_bot_bar || t_bot_stem;

    assign in_t = t_top || t_bot;

    // Priorità:
    // 1) T nere
    // 2) bordo cerchio nero
    // 3) interno cerchio bianco
    // 4) sfondo animato
    assign mix_r =
        in_t        ? 2'b00 :
        ring        ? 2'b00 :
        circle_fill ? 2'b11 :
                      bg_r;

    assign mix_g =
        in_t        ? 2'b00 :
        ring        ? 2'b00 :
        circle_fill ? 2'b11 :
                      bg_g;

    assign mix_b =
        in_t        ? 2'b00 :
        ring        ? 2'b00 :
        circle_fill ? 2'b11 :
                      bg_b;

    // ui_in[0] = inverti colori
    assign R = visible ? (ui_in[0] ? ~mix_r : mix_r) : 2'b00;
    assign G = visible ? (ui_in[0] ? ~mix_g : mix_g) : 2'b00;
    assign B = visible ? (ui_in[0] ? ~mix_b : mix_b) : 2'b00;

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule
