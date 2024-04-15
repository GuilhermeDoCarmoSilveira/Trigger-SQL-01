create database Ex01Trigger

go 

use Ex01Trigger

go


CREATE TABLE cliente (
codigo INT NOT NULL,
nome VARCHAR(70) NOT NULL
PRIMARY KEY(codigo)
)
GO
CREATE TABLE venda (
codigo_venda INT NOT NULL,
codigo_cliente INT NOT NULL,
valor_total DECIMAL(7,2) NOT NULL
PRIMARY KEY (codigo_venda)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)
GO
CREATE TABLE pontos (
codigo_cliente INT NOT NULL,
total_pontos DECIMAL(4,1) NOT NULL
PRIMARY KEY (codigo_cliente)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)

create trigger t_notdelvenda on venda
instead of update
as
begin
		rollback transaction
		
		declare @codVenda int
				

		set @codVenda = (select top 1 codigo_venda
						  from venda
						  order by codigo_venda desc)

		select c.nome, v.valor_total
		from cliente c, venda v
		where v.codigo_venda = @codVenda
end

go

create trigger t_pontos on venda 
after insert
as 
begin

		declare @pontos decimal(7,2),
				@codCliente int,
				@codClienteTeste int

		set @pontos = (select valor_total from inserted)

		set @pontos = @pontos * 0.1

		set @codCliente = (select codigo_cliente from inserted)

		set @codClienteTeste = (select codigo_cliente from pontos where codigo_cliente = @codCliente)

		if(@codClienteTeste is null)
		begin

				insert into pontos values (@codCliente, @pontos)
	
		end
		else
		begin

				update pontos
				set total_pontos = total_pontos + @pontos
				where codigo_cliente = @codCliente
		end

		set @pontos = (select total_pontos from pontos where codigo_cliente = @codCliente)

		if(@pontos >= 1)
		begin

				print ('Voce atingiu' + cast(@pontos as varchar(10)) + 'ponto(s)')
				
				update pontos
				set total_pontos = @pontos - 1
				where codigo_cliente = @codCliente

				set @pontos = @pontos - 1

				print ('Seus total de ponto(s) atual é de ' + cast(@pontos as varchar(10)))

		end
end

go

-- Inserir um novo cliente
INSERT INTO cliente (codigo, nome) VALUES (1, 'João Silva');

go

-- Inserir outro cliente
INSERT INTO cliente (codigo, nome) VALUES (2, 'Maria Oliveira');

go

-- Inserir uma nova venda para um cliente existente
INSERT INTO venda VALUES (1, 1, 100.00);

go

-- Inserir outra venda para um cliente existente
INSERT INTO venda VALUES (2, 2, 150.00)


-----------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE Produto (
    codigo INT PRIMARY KEY,
    nome VARCHAR(100),
    descricao VARCHAR(255),
    valor_unitario DECIMAL(7, 2)
)

go

CREATE TABLE Estoque (
    codigo_produto INT,
    qtd_estoque INT,
    estoque_minimo INT,
    PRIMARY KEY (codigo_produto)
)

go


CREATE TABLE Venda2 ( 
	nota_fiscal INT PRIMARY KEY, 
	codigo_produto INT REFERENCES Produto(codigo), 
	quantidade INT
)

go

create trigger t_vendaEstoque on venda2
after insert
as
begin

		declare	@codProd int,
				@qtdEstoque int,
				@qtdVenda int


		set @codProd = (select codigo_produto from inserted)

		set @qtdEstoque = (select qtd_estoque from Estoque where codigo_produto = @codProd)

		set @qtdVenda = (select quantidade from inserted)

		if(@qtdEstoque <= @qtdVenda)
		begin

			rollback transaction
			raiserror('quantidade indisponivel no momento', 16, 1)

		end
		else
		begin
				
			declare @qtdMin int 
			set @qtdMin = (select estoque_minimo from Estoque where codigo_produto = @codProd)

			if(@qtdEstoque < @qtdMin)
			begin

					print ('Esque a baixo do minimo')
			end

		end

		SELECT * FROM f_NotaFiscal((select nota_fiscal from inserted))
end

go

CREATE FUNCTION f_NotaFiscal(@nota int)
returns @tabela table (
	notaFiscal int,
	codProduto int,
	nome varchar(100),
	descricao varchar(255),
	valorUnit decimal(7, 2),
	qtd int,
	valorTotal decimal(7, 2)
)
begin
	

	 insert into @tabela (notaFiscal, codProduto, nome, descricao, valorUnit, qtd)
						  select v.nota_fiscal, p.codigo, p.nome, p.descricao, p.valor_unitario, v.quantidade 
						  from venda2 v, Produto p 
						  where v.codigo_produto = p.codigo

	declare @valorUnit  decimal(7, 2),
			@valorTotal decimal(7, 2)

	set @valorUnit = (select p.valor_unitario
					  from venda2 v, Produto p
					  where v.codigo_produto = p.codigo)

	set @valorTotal = (select quantidade from Venda2 where nota_fiscal = @nota) * @valorUnit

	update @tabela
	set valorTotal = @valorTotal
	where notaFiscal = @nota

	return
end


INSERT INTO Produto (codigo, nome, descricao, valor_unitario)VALUES (1, 'Camiseta', 'Camiseta de algodão branca', 29.99);

INSERT INTO Estoque (codigo_produto, qtd_estoque, estoque_minimo)VALUES (1, 50, 10);

INSERT INTO Venda2 (nota_fiscal, codigo_produto, quantidade)VALUES (1001, 1, 3);