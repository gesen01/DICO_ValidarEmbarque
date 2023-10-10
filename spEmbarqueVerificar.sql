SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
GO

IF EXISTS(SELECT * FROM sysobjects WHERE TYPE='p' AND NAME='spEmbarqueVerificar')
DROP PROCEDURE spEmbarqueVerificar
GO
CREATE PROCEDURE spEmbarqueVerificar
@ID               		int,
@Accion			char(20),
@Empresa          		char(5),
@Usuario			char(10),
@Modulo	      		char(5),
@Mov              		char(20),
@MovID			varchar(20),
@MovTipo	      		char(20),
@FechaEmision		datetime,
@Estatus			char(15),
@EstatusNuevo		char(15),
@Vehiculo			char(10),
@PersonalCobrador		varchar(10),
@Conexion			bit,
@SincroFinal		bit,
@Sucursal			int,
@CfgDesembarquesParciales   bit,
@AntecedenteID		int	     OUTPUT,
@AntecedenteMovTipo		char(20)     OUTPUT,
@Ok               		int          OUTPUT,
@OkRef            		varchar(255) OUTPUT
WITH ENCRYPTION
AS BEGIN
DECLARE
@ModuloID	int,
@EstadoTipo char(20),
@Cliente	char(10),
@Proveedor	char(10),
@Importe	money
IF @Accion = 'CANCELAR'
BEGIN
IF EXISTS(SELECT * FROM EmbarqueD WHERE ID = @ID AND DesembarqueParcial = 1)
SELECT @Ok = 42050
RETURN
/*IF @Conexion = 0
IF EXISTS (SELECT * FROM MovFlujo WHERE Cancelado = 0 AND Empresa = @Empresa AND OModulo = @Modulo AND OID = @ID AND OModulo <> DModulo)
SELECT @Ok = 60070*/
END
ELSE BEGIN
IF @Estatus = 'SINAFECTAR'
BEGIN
IF NOT EXISTS(SELECT * FROM EmbarqueD WHERE ID = @ID) SELECT @Ok = 60010
--10/10/2023. IGGR. Se bloquea la siguiente linea que valida que los vehiculos se encuentren aun entransito
--IF (SELECT Estatus FROM Vehiculo WHERE Vehiculo = @Vehiculo) = 'ENTRANSITO' SELECT @Ok = 42010
ELSE BEGIN
SELECT @ModuloID = NULL
SELECT @ModuloID = MIN(e.ModuloID) FROM EmbarqueDArt e, VentaD d WHERE e.ID = @ID AND e.Modulo = 'VTAS' AND e.ModuloID = d.ID AND e.Renglon = d.Renglon AND e.RenglonSub = d.RenglonSub AND (e.Cantidad<0 OR e.Cantidad>(d.Cantidad-ISNULL(d.CantidadCancelada, 0)-ISNULL(d.CantidadEmbarcada, 0)))
IF @ModuloID IS NOT NULL
SELECT @Ok = 20010, @OkRef = RTRIM(Mov)+' '+RTRIM(MovID) FROM Venta WHERE ID = @ModuloID
END
END
/*IF @EstatusNuevo = 'CONCLUIDO'
BEGIN
IF @Cxp = 1
BEGIN
IF @CxpProveedor IS NULL SELECT @Ok = 40020 ELSE
IF @CxpImporte + @CxpImpuestos = 0.0 SELECT @Ok = 40140
END
END*/
IF @Estatus = 'PENDIENTE'
BEGIN
DECLARE crEstado CURSOR FOR
SELECT RTRIM(UPPER(e.Tipo)), NULLIF(RTRIM(m.Cliente), ''), NULLIF(RTRIM(m.Proveedor), ''), ISNULL(d.Importe, 0.0)
FROM EmbarqueD d
JOIN EmbarqueMov m ON d.EmbarqueMov = m.ID
LEFT OUTER JOIN EmbarqueEstado e ON d.Estado = e.Estado
WHERE d.ID = @ID
OPEN crEstado
FETCH NEXT FROM crEstado INTO @EstadoTipo, @Cliente, @Proveedor, @Importe
WHILE @@FETCH_STATUS <> -1 AND @Ok IS NULL
BEGIN
IF @@FETCH_STATUS <> -2 AND @Ok IS NULL
BEGIN
IF @EstadoTipo = 'PENDIENTE' AND @CfgDesembarquesParciales = 0 SELECT @Ok = 30340 ELSE
IF @EstadoTipo IN (NULL, '') SELECT @Ok = 30340 ELSE
IF @EstadoTipo = 'COBRADO' AND @Cliente IS NULL SELECT @Ok = 20180 ELSE
IF @EstadoTipo = 'PAGADO' AND @Proveedor IS NULL SELECT @Ok = 20180 ELSE
IF @EstadoTipo IN ('COBRADO', 'PAGADO') AND @Importe = 0.0 SELECT @Ok = 40140
END
FETCH NEXT FROM crEstado INTO @EstadoTipo, @Cliente, @Proveedor, @Importe
END
CLOSE crEstado
DEALLOCATE crEstado
END
END
RETURN
END
GO