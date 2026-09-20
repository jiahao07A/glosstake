import {useAppDispatch, useAppSelector} from './redux'
import React, {useCallback} from 'react'
import {setNeedScroll} from '../redux/envReducer'
import { useMessage } from './useMessageService'
const useSubtitle = () => {
  const dispatch = useAppDispatch()
  const envData = useAppSelector(state => state.env.envData)
  const {sendInject} = useMessage(!!envData.sidePanel)

  const move = useCallback((time: number, togglePause: boolean) => {
    sendInject(null, 'MOVE', {time, togglePause})
  }, [sendInject])

  const scrollIntoView = useCallback((ref: React.RefObject<HTMLDivElement>) => {
    ref.current?.scrollIntoView({behavior: 'smooth', block: 'center'})
    dispatch(setNeedScroll(false))
  }, [dispatch])

  return {move, scrollIntoView}
}

export default useSubtitle
